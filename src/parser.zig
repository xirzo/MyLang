const std = @import("std");
const l = @import("lexer.zig");
const v = @import("value.zig");
const e = @import("expression.zig");
const p = @import("program.zig");
const s = @import("statement.zig");
const errors = @import("errors.zig");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: l.Lexer,

    pub fn init(allocator: std.mem.Allocator, lexer: l.Lexer) Parser {
        return Parser{
            .allocator = allocator,
            .lexer = lexer,
        };
    }

    pub fn parse(self: *Parser) errors.ParseError!*p.Program {
        var program = try self.allocator.create(p.Program);
        program.* = try p.Program.init(self.allocator);

        while (true) {
            const tok = self.lexer.peek();

            if (tok == .eof) {
                break;
            }

            if (tok == .eol) {
                _ = self.lexer.next();
                continue;
            }

            if (try self.parseStatement()) |statement| {
                try program.statements.append(statement);
                std.log.debug("parsed statement\n", .{});
            } else {
                _ = self.lexer.next();
            }

            const next_tok = self.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = self.lexer.next();
            }
        }

        return program;
    }

    fn parseExpression(parser: *Parser) !*e.Expression {
        return try parser.expression(0);
    }

    fn prefixBindingPower(operator: u8) ?u8 {
        return switch (operator) {
            '+', '-' => 5,
            else => null,
        };
    }

    fn infixBindingPower(operator: u8) ?struct { u8, u8 } {
        return switch (operator) {
            '=' => .{ 1, 2 },
            '+', '-' => .{ 2, 3 },
            '*', '/' => .{ 3, 4 },
            else => null,
        };
    }

    fn comparisonBindingPower(lexem: l.Lexeme) ?struct { u8, u8 } {
        return switch (lexem) {
            .eq, .noteq, .greater, .greatereq, .less, .lesseq => .{ 2, 3 },
            else => null,
        };
    }

    fn postfixBindingPower(operator: u8) ?u8 {
        return switch (operator) {
            '!' => 8,
            '[' => 9,
            '.' => 10,
            else => null,
        };
    }

    fn expression(self: *Parser, min_binding_power: u8) errors.ParseError!*e.Expression {
        const lex_item: l.Lexeme = self.lexer.next();

        var lhs: *e.Expression = switch (lex_item) {
            .number => |num| blk: {
                const expr_node: *e.Expression = try self.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .number = num } };
                break :blk expr_node;
            },
            .string => |str| blk: {
                const expr_node: *e.Expression = try self.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .string = str } };
                break :blk expr_node;
            },
            .true_literal => blk: {
                const expr_node: *e.Expression = try self.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .boolean = true } };
                break :blk expr_node;
            },
            .false_literal => blk: {
                const expr_node: *e.Expression = try self.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .boolean = false } };
                break :blk expr_node;
            },
            .ident => |name| blk: {
                if (!self.lexer.checkToken(.lparen)) {
                    const name_copy = try self.allocator.dupe(u8, name);
                    const expr_node: *e.Expression = try self.allocator.create(e.Expression);
                    expr_node.* = e.Expression{ .variable = .{ .name = name_copy } };
                    break :blk expr_node;
                }

                _ = self.lexer.next();

                var parameters = std.array_list.Managed(*e.Expression).init(self.allocator);

                if (!self.lexer.checkToken(.rparen)) {
                    while (true) {
                        const param_expr = try self.expression(0);
                        try parameters.append(param_expr);

                        const next_token = self.lexer.next();

                        if (next_token == .rparen) {
                            break;
                        } else if (next_token == .comma) {
                            continue;
                        } else {
                            for (parameters.items) |param| {
                                param.deinit(self.allocator);
                                self.allocator.destroy(param);
                            }
                            parameters.deinit();
                            return error.ExpectedCommaOrRParen;
                        }
                    }
                } else {
                    _ = self.lexer.next();
                }

                const expr_node = try self.allocator.create(e.Expression);

                expr_node.* = e.Expression{
                    .function_call = .{
                        .function_name = name,
                        .parameters = parameters,
                    },
                };

                break :blk expr_node;
            },
            .lparen => blk: {
                const lhs_expr = try self.expression(0);
                std.debug.assert(self.lexer.next() == .rparen);
                break :blk lhs_expr;
            },
            .sq_lbracket => blk: {
                var elements = std.array_list.Managed(*e.Expression).init(self.allocator);

                while (!self.lexer.checkToken(.sq_rbracket)) {
                    const element = try self.expression(0);

                    try elements.append(element);

                    if (self.lexer.checkToken(.comma)) {
                        _ = self.lexer.next();
                    }
                }

                std.debug.assert(self.lexer.next() == .sq_rbracket);

                const node = try self.allocator.create(e.Expression);
                node.* = e.Expression{ .constant = .{ .array = elements } };

                break :blk node;
            },
            .lbrace => blk: {
                var object_fields = std.array_list.Managed(e.ObjectField).init(self.allocator);
                errdefer {
                    for (object_fields.items) |*field| {
                        self.allocator.free(field.key);
                        field.value.deinit(self.allocator);
                        self.allocator.destroy(field.value);
                    }
                    object_fields.deinit();
                }

                while (!self.lexer.checkToken(.rbrace)) {
                    while (self.lexer.checkToken(.eol)) {
                        _ = self.lexer.next();
                    }

                    if (self.lexer.checkToken(.rbrace)) {
                        break;
                    }

                    const key_token = self.lexer.next();
                    const key = switch (key_token) {
                        .ident => |name| try self.allocator.dupe(u8, name),
                        .string => |str| try self.allocator.dupe(u8, str),
                        else => {
                            std.log.err("expected identifier or string for object key, got {any}", .{key_token});
                            return error.ExpectedIdentifier;
                        },
                    };
                    errdefer self.allocator.free(key);

                    const assign_token = self.lexer.next();
                    if (assign_token != .assign) {
                        std.log.err("expected '=' after object key, got {any}", .{assign_token});
                        self.allocator.free(key);
                        return error.ExpectedAssignment;
                    }

                    const value = try self.expression(0);

                    try object_fields.append(e.ObjectField{
                        .key = key,
                        .value = value,
                    });

                    while (self.lexer.checkToken(.eol)) {
                        _ = self.lexer.next();
                    }

                    if (self.lexer.checkToken(.comma)) {
                        _ = self.lexer.next();
                        while (self.lexer.checkToken(.eol)) {
                            _ = self.lexer.next();
                        }
                    } else if (!self.lexer.checkToken(.rbrace)) {
                        std.log.err("expected ',' or '}}' in object literal, got {any}", .{self.lexer.peek()});
                        return error.MissingComma;
                    }
                }

                std.debug.assert(self.lexer.next() == .rbrace);

                const node = try self.allocator.create(e.Expression);
                node.* = e.Expression{ .constant = .{ .object = object_fields } };

                break :blk node;
            },
            else => blk: {
                if (lex_item.getOperatorChar()) |char| {
                    if (prefixBindingPower(char)) |r_bp| {
                        const rhs = try self.expression(r_bp);
                        const expr_node = try self.allocator.create(e.Expression);
                        expr_node.* = e.Expression{ .binary_operator = .{ .lhs = null, .rhs = rhs, .value = char } };
                        break :blk expr_node;
                    } else {
                        std.log.err("operator cannot be used as prefix {any}\n", .{lex_item});
                        return error.ParseError;
                    }
                } else {
                    std.log.err("bad lexeme for expression parse {any}\n", .{lex_item});
                    return error.BadExpressionLexeme;
                }
            },
        };

        while (true) {
            const oper_lex: l.Lexeme = self.lexer.peek();

            if (oper_lex.getComparisonOp()) |comp_op| {
                if (comparisonBindingPower(oper_lex)) |bp| {
                    const l_bp = bp[0];
                    const r_bp = bp[1];

                    if (min_binding_power > l_bp) {
                        break;
                    }

                    _ = self.lexer.next();
                    const rhs = try self.expression(r_bp);

                    const new_lhs = try self.allocator.create(e.Expression);
                    new_lhs.* = e.Expression{
                        .comparison_operator = .{
                            .op = comp_op,
                            .lhs = lhs,
                            .rhs = rhs,
                        },
                    };
                    lhs = new_lhs;
                    continue;
                }
            }

            const oper_char: u8 = switch (oper_lex) {
                .eof => break,
                else => blk: {
                    const maybe_char = oper_lex.getOperatorChar();
                    if (maybe_char == null) break;
                    break :blk maybe_char.?;
                },
            };

            if (postfixBindingPower(oper_char)) |l_bp| {
                if (min_binding_power > l_bp) {
                    break;
                }

                _ = self.lexer.next();

                const new_lhs = try self.allocator.create(e.Expression);

                new_lhs.* = switch (oper_char) {
                    '[' => blk: {
                        const rhs = try self.expression(0);

                        std.debug.assert(self.lexer.next() == .sq_rbracket);

                        break :blk e.Expression{ .binary_operator = .{ .lhs = lhs, .rhs = rhs, .value = '[' } };
                    },
                    '.' => blk: {
                        const key_token = self.lexer.next();

                        std.debug.assert(key_token == .ident);

                        const key = try self.allocator.dupe(u8, key_token.ident);

                        break :blk e.Expression{ .object_access = .{ .key = key, .object = lhs } };
                    },

                    else => e.Expression{ .binary_operator = .{ .lhs = lhs, .rhs = null, .value = oper_char } },
                };

                lhs = new_lhs;
                continue;
            }

            if (infixBindingPower(oper_char)) |bp| {
                const l_bp = bp[0];
                const r_bp = bp[1];

                if (min_binding_power > l_bp) {
                    break;
                }

                _ = self.lexer.next();

                const rhs = try self.expression(r_bp);

                const new_lhs = try self.allocator.create(e.Expression);
                new_lhs.* = e.Expression{
                    .binary_operator = .{
                        .value = oper_char,
                        .lhs = lhs,
                        .rhs = rhs,
                    },
                };
                lhs = new_lhs;
                continue;
            }

            break;
        }

        return lhs;
    }

    fn parseStatement(self: *Parser) errors.ParseError!?*s.Statement {
        const tok = self.lexer.peek();

        std.log.debug("got lexeme: {s}\n", .{@tagName(tok)});

        return switch (tok) {
            .let => try self.parseLet(),
            .lbrace => try self.parseBlock(),
            .function => try self.parseFunctionDeclaration(),
            .ret => try self.parseReturn(),
            .if_cond => try self.parseIf(),
            .while_loop => try self.parseWhile(),
            .for_loop => try self.parseFor(),
            .ident => blk: {
                if (self.lexer.checkNextToken(.assign)) {
                    break :blk try self.parseAssignment();
                } else {
                    const expr_node = try self.parseExpression();
                    const stmt_node = try self.allocator.create(s.Statement);
                    stmt_node.* = s.Statement{ .expression = .{ .expression = expr_node } };
                    break :blk stmt_node;
                }
            },
            else => blk: {
                if (tok == .semicolon or tok == .eol or tok == .eof) {
                    return null;
                }

                const expr_node = try self.parseExpression();
                const stmt_node = try self.allocator.create(s.Statement);
                stmt_node.* = s.Statement{ .expression = .{ .expression = expr_node } };
                break :blk stmt_node;
            },
        };
    }

    fn parseLet(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const ident_lex = self.lexer.next();

        if (ident_lex != .ident) {
            std.log.err("expected identifier after 'let', got {any}", .{ident_lex});
            return error.ExpectedIdentifier;
        }

        const var_name = ident_lex.ident;
        const name_copy = try self.allocator.dupe(u8, var_name);
        const equal_lex = self.lexer.next();

        if (equal_lex != .assign) {
            std.log.err("expected '=' after variable name, got {any}", .{equal_lex});
            self.allocator.free(name_copy);
            return error.ExpectedAssignment;
        }

        const value = try self.parseExpression();

        const let_stmt = try self.allocator.create(s.Statement);

        let_stmt.* = s.Statement{
            .let = .{
                .name = name_copy,
                .value = value,
            },
        };

        return let_stmt;
    }

    fn parseBlock(self: *Parser) errors.ParseError!*s.Statement {
        if (!self.lexer.checkToken(.lbrace)) {
            std.log.err("expected '{{' at start of block, got {s}", .{@tagName(self.lexer.peek())});
            return error.MissingOpeningBrace;
        }

        _ = self.lexer.next();

        var block_statements = std.array_list.Managed(*s.Statement).init(self.allocator);
        var block_environment = std.StringHashMap(v.Value).init(self.allocator);

        errdefer {
            for (block_statements.items) |statement| {
                statement.deinit(self.allocator);
                self.allocator.destroy(statement);
            }
            block_statements.deinit();
            block_environment.deinit();
        }

        while (!self.lexer.checkToken(.rbrace)) {
            if (self.lexer.checkToken(.eof)) {
                std.log.err("unexpected end of file while parsing block", .{});
                return error.UnexpectedEOF;
            }

            if (self.lexer.checkToken(.eol)) {
                _ = self.lexer.next();
                continue;
            }

            if (try self.parseStatement()) |statement| {
                try block_statements.append(statement);
            }

            const next_tok = self.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = self.lexer.next();
            }
        }

        _ = self.lexer.next();

        const block_stmt = try self.allocator.create(s.Statement);

        block_stmt.* = s.Statement{ .block = .{
            .statements = block_statements,
            .environment = block_environment,
        } };

        return block_stmt;
    }

    fn parseFunctionDeclaration(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const ident_lex = self.lexer.next();
        if (ident_lex != .ident) {
            std.log.err("expected identifier after 'fn' keyword, got {s}", .{@tagName(self.lexer.peek())});
            return error.ExpectedIdentifier;
        }
        const ident = ident_lex.ident;

        if (self.lexer.next() != .lparen) {
            std.log.err("expected '(' after function name, got {s}", .{@tagName(self.lexer.peek())});
            return error.MissingOpeningParenthesis;
        }

        var parameters = std.array_list.Managed([]const u8).init(self.allocator);

        if (!self.lexer.checkToken(.rparen)) {
            while (true) {
                const param_lex = self.lexer.next();

                if (param_lex != .ident) {
                    std.log.err("expected parameter identifier, got {s}", .{@tagName(param_lex)});
                    for (parameters.items) |param_name| {
                        self.allocator.free(param_name);
                    }
                    parameters.deinit();
                    return error.MissingParameter;
                }

                const parameter_name = try self.allocator.dupe(u8, param_lex.ident);
                try parameters.append(parameter_name);

                const next_tok = self.lexer.peek();
                if (next_tok == .rparen) {
                    break;
                } else if (next_tok == .comma) {
                    _ = self.lexer.next();
                    continue;
                } else {
                    std.log.err("expected comma or ')' after parameter, got {s}", .{@tagName(next_tok)});
                    for (parameters.items) |param_name| {
                        self.allocator.free(param_name);
                    }
                    parameters.deinit();
                    return error.MissingComma;
                }
            }
        }

        if (self.lexer.next() != .rparen) {
            std.log.err("expected ')' after parameter list, got {s}", .{@tagName(self.lexer.peek())});
            for (parameters.items) |param_name| {
                self.allocator.free(param_name);
            }
            parameters.deinit();
            return error.MissingClosingParenthesis;
        }

        const block_stmt = try self.parseBlock();

        const block_ptr = try self.allocator.create(s.Block);
        errdefer self.allocator.destroy(block_ptr);

        switch (block_stmt.*) {
            .block => |*blk| {
                block_ptr.* = s.Block{
                    .statements = blk.statements,
                    .environment = blk.environment,
                };
                blk.statements = std.array_list.Managed(*s.Statement).init(self.allocator);
                blk.environment = std.StringHashMap(v.Value).init(self.allocator);
            },
            else => {
                self.allocator.destroy(block_ptr);
                self.allocator.destroy(block_stmt);
                for (parameters.items) |param_name| {
                    self.allocator.free(param_name);
                }
                parameters.deinit();
                return error.ParseError;
            },
        }

        const function_declaration = try self.allocator.create(s.Statement);

        function_declaration.* = s.Statement{
            .function_declaration = .{
                .name = ident,
                .block = block_ptr,
                .parameters = parameters,
            },
        };

        self.allocator.destroy(block_stmt);

        return function_declaration;
    }

    fn parseReturn(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();

        const ret_stmt = try self.allocator.create(s.Statement);
        errdefer self.allocator.destroy(ret_stmt);

        ret_stmt.* = .{ .ret = .{
            .value = value,
        } };

        return ret_stmt;
    }

    fn parseIf(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();
        const block_stmt = try self.parseBlock();

        const block_ptr = try self.allocator.create(s.Block);
        errdefer self.allocator.destroy(block_ptr);

        switch (block_stmt.*) {
            .block => |block| {
                block_ptr.* = block;
            },
            else => {
                self.allocator.destroy(block_ptr);
                self.allocator.destroy(block_stmt);
                return error.ParseError;
            },
        }

        const if_stmt = try self.allocator.create(s.Statement);
        if_stmt.* = .{ .if_cond = .{ .body = block_ptr, .condition = value } };

        self.allocator.destroy(block_stmt);

        return if_stmt;
    }

    fn parseWhile(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();
        const block_stmt = try self.parseBlock();

        const block_ptr = try self.allocator.create(s.Block);
        errdefer self.allocator.destroy(block_ptr);

        switch (block_stmt.*) {
            .block => |block| {
                block_ptr.* = block;
            },
            else => {
                self.allocator.destroy(block_ptr);
                self.allocator.destroy(block_stmt);
                return error.ParseError;
            },
        }

        const while_stmt = try self.allocator.create(s.Statement);
        while_stmt.* = .{ .while_loop = .{ .body = block_ptr, .condition = value } };

        self.allocator.destroy(block_stmt);

        return while_stmt;
    }

    fn parseFor(self: *Parser) errors.ParseError!*s.Statement {
        _ = self.lexer.next();

        const init_stmt = try self.parseStatement();
        if (init_stmt == null) {
            return error.ParseError;
        }

        if (!self.lexer.checkToken(.semicolon)) {
            if (init_stmt) |stmtt| {
                stmtt.deinit(self.allocator);
                self.allocator.destroy(stmtt);
            }
            return error.ExpectedSemicolon;
        }
        _ = self.lexer.next();

        const condition = try self.parseExpression();

        if (!self.lexer.checkToken(.semicolon)) {
            condition.deinit(self.allocator);
            self.allocator.destroy(condition);

            if (init_stmt) |stmtt| {
                stmtt.deinit(self.allocator);
                self.allocator.destroy(stmtt);
            }
            return error.ExpectedSemicolon;
        }
        _ = self.lexer.next();

        const increment = try self.parseStatement();
        if (increment == null) {
            condition.deinit(self.allocator);
            self.allocator.destroy(condition);
            if (init_stmt) |stmtt| {
                stmtt.deinit(self.allocator);
                self.allocator.destroy(stmtt);
            }
            return error.ParseError;
        }

        const block_stmt = try self.parseBlock();
        const block_ptr = try self.allocator.create(s.Block);
        errdefer self.allocator.destroy(block_ptr);

        switch (block_stmt.*) {
            .block => |block| {
                block_ptr.* = block;
            },
            else => {
                self.allocator.destroy(block_ptr);
                block_stmt.deinit(self.allocator);
                self.allocator.destroy(block_stmt);
                return error.ParseError;
            },
        }

        // NOTE: allows only let statements, maybe sufficient
        // to just check for null
        switch (init_stmt.?.*) {
            .let => {},
            else => {
                self.allocator.destroy(block_ptr);
                block_stmt.deinit(self.allocator);
                self.allocator.destroy(block_stmt);
                if (init_stmt) |stmtt| {
                    stmtt.deinit(self.allocator);
                    self.allocator.destroy(stmtt);
                }
                return error.ParseError;
            },
        }

        const for_stmt = try self.allocator.create(s.Statement);
        for_stmt.* = .{
            .for_loop = .{
                .init = init_stmt.?,
                .condition = condition,
                .increment = increment.?,
                .body = block_ptr,
            },
        };

        self.allocator.destroy(block_stmt);
        return for_stmt;
    }

    fn parseAssignment(self: *Parser) errors.ParseError!*s.Statement {
        const ident_lex = self.lexer.next();

        if (ident_lex != .ident) {
            std.log.err("expected identifier for assignment, got {any}", .{ident_lex});
            return error.ExpectedIdentifier;
        }

        const var_name = ident_lex.ident;
        const name_copy = try self.allocator.dupe(u8, var_name);

        const equal_lex = self.lexer.next();
        if (equal_lex != .assign) {
            std.log.err("expected '=' after variable name, got {any}", .{equal_lex});
            self.allocator.free(name_copy);
            return error.ExpectedAssignment;
        }

        const value = try self.parseExpression();

        const assign_stmt = try self.allocator.create(s.Statement);
        assign_stmt.* = s.Statement{
            .assignment = .{
                .name = name_copy,
                .value = value,
            },
        };

        return assign_stmt;
    }
};
