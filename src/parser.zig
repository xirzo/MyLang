const std = @import("std");
const lex = @import("lexer.zig");
const v = @import("value.zig");
const e = @import("expression.zig");
const pg = @import("program.zig");
const stmt = @import("statement.zig");
const assert = std.debug.assert;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    MissingClosingBrace,
    MissingOpeningBrace,
    MissingClosingParenthesis,
    MissingOpeningParenthesis,
    MissingParameter,
    MissingComma,

    InvalidPrefixOperator,
    InvalidInfixOperator,
    InvalidPostfixOperator,
    BadExpressionLexeme,

    ExpectedIdentifier,
    ExpectedAssignment,
    ExpectedSemicolon,
    ExpectedRParen,
    ExpectedCommaOrRParen,

    OutOfMemory,
    ParseError,
};

pub const Parser = struct {
    lexer: lex.Lexer,
    allocator: std.mem.Allocator,

    pub fn init(l: lex.Lexer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .lexer = l,
            .allocator = allocator,
        };
    }

    pub fn parse(p: *Parser) ParseError!*pg.Program {
        var program = try p.allocator.create(pg.Program);
        program.* = try pg.Program.init(p.allocator);

        std.log.debug("start parsing\n", .{});

        while (true) {
            const tok = p.lexer.peek();

            if (tok == .eof) {
                break;
            }

            if (tok == .eol) {
                _ = p.lexer.next();
                continue;
            }

            if (try p.parseStatement()) |statement| {
                try program.statements.append(statement);
                std.log.debug("parsed statement\n", .{});
            } else {
                _ = p.lexer.next();
            }

            const next_tok = p.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = p.lexer.next();
            }
        }

        program.initEvaluator();
        return program;
    }

    pub fn parseExpression(p: *Parser) !*e.Expression {
        return try p.expression(0);
    }

    fn prefixBindingPower(op: u8) ?u8 {
        return switch (op) {
            '+', '-' => 5,
            else => null,
        };
    }

    fn infixBindingPower(op: u8) ?struct { u8, u8 } {
        return switch (op) {
            '=' => .{ 1, 2 },
            '+', '-' => .{ 2, 3 },
            '*', '/' => .{ 3, 4 },
            else => null,
        };
    }

    fn comparisonBindingPower(lexem: lex.Lexeme) ?struct { u8, u8 } {
        return switch (lexem) {
            .eq, .noteq, .greater, .greatereq, .less, .lesseq => .{ 2, 3 },
            else => null,
        };
    }

    fn postfixBindingPower(op: u8) ?u8 {
        return switch (op) {
            '!' => 8,
            '[' => 9,
            '.' => 10,
            else => null,
        };
    }

    fn expression(p: *Parser, min_bp: u8) ParseError!*e.Expression {
        const lex_item: lex.Lexeme = p.lexer.next();

        var lhs: *e.Expression = switch (lex_item) {
            .number => |num| blk: {
                const expr_node: *e.Expression = try p.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .number = num } };
                break :blk expr_node;
            },
            .string => |str| blk: {
                const expr_node: *e.Expression = try p.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .string = str } };
                break :blk expr_node;
            },
            .true_literal => blk: {
                const expr_node: *e.Expression = try p.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .boolean = true } };
                break :blk expr_node;
            },
            .false_literal => blk: {
                const expr_node: *e.Expression = try p.allocator.create(e.Expression);
                expr_node.* = e.Expression{ .constant = .{ .boolean = false } };
                break :blk expr_node;
            },
            .ident => |name| blk: {
                if (p.lexer.peek() != .lparen) {
                    // just a variable
                    const name_copy = try p.allocator.dupe(u8, name);
                    const expr_node: *e.Expression = try p.allocator.create(e.Expression);
                    expr_node.* = e.Expression{ .variable = .{ .name = name_copy } };
                    break :blk expr_node;
                }

                _ = p.lexer.next();

                var parameters = std.array_list.Managed(*e.Expression).init(p.allocator);

                if (p.lexer.peek() != .rparen) {
                    while (true) {
                        const param_expr = try p.expression(0);
                        try parameters.append(param_expr);

                        const next_token = p.lexer.next();

                        if (next_token == .rparen) {
                            break;
                        } else if (next_token == .comma) {
                            continue;
                        } else {
                            for (parameters.items) |param| {
                                param.deinit(p.allocator);
                                p.allocator.destroy(param);
                            }
                            parameters.deinit();
                            return error.ExpectedCommaOrRParen;
                        }
                    }
                } else {
                    _ = p.lexer.next();
                }

                const expr_node = try p.allocator.create(e.Expression);

                expr_node.* = e.Expression{
                    .function_call = .{
                        .function_name = name,
                        .parameters = parameters,
                    },
                };

                break :blk expr_node;
            },
            .lparen => blk: {
                const lhs_expr = try p.expression(0);
                assert(p.lexer.next() == .rparen);
                break :blk lhs_expr;
            },
            .sq_lbracket => blk: {
                var elements = std.array_list.Managed(*e.Expression).init(p.allocator);

                while (p.lexer.peek() != .sq_rbracket) {
                    const element = try p.expression(0);

                    try elements.append(element);

                    if (p.lexer.peek() == .comma) {
                        _ = p.lexer.next();
                    }
                }

                assert(p.lexer.next() == .sq_rbracket);

                const node = try p.allocator.create(e.Expression);
                node.* = e.Expression{ .constant = .{ .array = elements } };

                break :blk node;
            },
            .lbrace => blk: {
                var object_fields = std.array_list.Managed(e.ObjectField).init(p.allocator);
                errdefer {
                    for (object_fields.items) |*field| {
                        p.allocator.free(field.key);
                        field.value.deinit(p.allocator);
                        p.allocator.destroy(field.value);
                    }
                    object_fields.deinit();
                }

                while (p.lexer.peek() != .rbrace) {
                    while (p.lexer.peek() == .eol) {
                        _ = p.lexer.next();
                    }

                    if (p.lexer.peek() == .rbrace) {
                        break;
                    }

                    const key_token = p.lexer.next();
                    const key = switch (key_token) {
                        .ident => |name| try p.allocator.dupe(u8, name),
                        .string => |str| try p.allocator.dupe(u8, str),
                        else => {
                            std.log.err("expected identifier or string for object key, got {any}", .{key_token});
                            return error.ExpectedIdentifier;
                        },
                    };
                    errdefer p.allocator.free(key);

                    const assign_token = p.lexer.next();
                    if (assign_token != .assign) {
                        std.log.err("expected '=' after object key, got {any}", .{assign_token});
                        p.allocator.free(key);
                        return error.ExpectedAssignment;
                    }

                    const value = try p.expression(0);

                    try object_fields.append(e.ObjectField{
                        .key = key,
                        .value = value,
                    });

                    while (p.lexer.peek() == .eol) {
                        _ = p.lexer.next();
                    }

                    if (p.lexer.peek() == .comma) {
                        _ = p.lexer.next();
                        while (p.lexer.peek() == .eol) {
                            _ = p.lexer.next();
                        }
                    } else if (p.lexer.peek() != .rbrace) {
                        std.log.err("expected ',' or '}}' in object literal, got {any}", .{p.lexer.peek()});
                        return error.MissingComma;
                    }
                }

                assert(p.lexer.next() == .rbrace);

                const node = try p.allocator.create(e.Expression);
                node.* = e.Expression{ .constant = .{ .object = object_fields } };

                break :blk node;
            },
            else => blk: {
                if (lex_item.getOperatorChar()) |char| {
                    if (prefixBindingPower(char)) |r_bp| {
                        const rhs = try p.expression(r_bp);
                        const expr_node = try p.allocator.create(e.Expression);
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
            const oper_lex: lex.Lexeme = p.lexer.peek();

            if (oper_lex.getComparisonOp()) |comp_op| {
                if (comparisonBindingPower(oper_lex)) |bp| {
                    const l_bp = bp[0];
                    const r_bp = bp[1];

                    if (min_bp > l_bp) {
                        break;
                    }

                    _ = p.lexer.next();
                    const rhs = try p.expression(r_bp);

                    const new_lhs = try p.allocator.create(e.Expression);
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
                if (min_bp > l_bp) {
                    break;
                }

                _ = p.lexer.next();

                const new_lhs = try p.allocator.create(e.Expression);

                new_lhs.* = switch (oper_char) {
                    '[' => blk: {
                        const rhs = try p.expression(0);

                        assert(p.lexer.next() == .sq_rbracket);

                        break :blk e.Expression{ .binary_operator = .{ .lhs = lhs, .rhs = rhs, .value = '[' } };
                    },
                    '.' => blk: {
                        const key_token = p.lexer.next();

                        assert(key_token == .ident);

                        const key = try p.allocator.dupe(u8, key_token.ident);

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

                if (min_bp > l_bp) {
                    break;
                }

                _ = p.lexer.next();

                const rhs = try p.expression(r_bp);

                const new_lhs = try p.allocator.create(e.Expression);
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

    pub fn parseStatement(p: *Parser) ParseError!?*stmt.Statement {
        const tok = p.lexer.peek();

        std.log.debug("got lexeme: {s}\n", .{@tagName(tok)});

        return switch (tok) {
            .let => try p.parseLet(),
            .lbrace => try p.parseBlock(),
            .function => try p.parseFunctionDeclaration(),
            .ret => try p.parseReturn(),
            .if_cond => try p.parseIf(),
            .while_loop => try p.parseWhile(),
            // NOTE: parsing function calls may produce errors when creating expression
            // statement like:
            // x + 5 (cause x is ident is goes before 5),
            // 5 + x should work
            else => blk: {
                if (tok == .semicolon or tok == .eol or tok == .eof) {
                    return null;
                }

                const expr_node = try p.parseExpression();
                const stmt_node = try p.allocator.create(stmt.Statement);
                stmt_node.* = stmt.Statement{ .expression = .{ .expression = expr_node } };
                break :blk stmt_node;
            },
        };
    }

    fn parseLet(p: *Parser) ParseError!*stmt.Statement {
        _ = p.lexer.next();

        const ident_lex = p.lexer.next();

        if (ident_lex != .ident) {
            std.log.err("expected identifier after 'let', got {any}", .{ident_lex});
            return error.ExpectedIdentifier;
        }

        const var_name = ident_lex.ident;
        const name_copy = try p.allocator.dupe(u8, var_name);
        const equal_lex = p.lexer.next();

        if (equal_lex != .assign) {
            std.log.err("expected '=' after variable name, got {any}", .{equal_lex});
            p.allocator.free(name_copy);
            return error.ExpectedAssignment;
        }

        const value = try p.parseExpression();

        const let_stmt = try p.allocator.create(stmt.Statement);

        let_stmt.* = stmt.Statement{
            .let = .{
                .name = name_copy,
                .value = value,
            },
        };

        return let_stmt;
    }

    fn parseBlock(p: *Parser) ParseError!*stmt.Statement {
        if (p.lexer.peek() != .lbrace) {
            std.log.err("expected '{{' at start of block, got {s}", .{@tagName(p.lexer.peek())});
            return error.MissingOpeningBrace;
        }

        _ = p.lexer.next();

        var block_statements = std.array_list.Managed(*stmt.Statement).init(p.allocator);
        var block_environment = std.StringHashMap(v.Value).init(p.allocator);

        errdefer {
            for (block_statements.items) |statement| {
                statement.deinit(p.allocator);
                p.allocator.destroy(statement);
            }
            block_statements.deinit();
            block_environment.deinit();
        }

        while (p.lexer.peek() != .rbrace) {
            if (p.lexer.peek() == .eof) {
                std.log.err("unexpected end of file while parsing block", .{});
                return error.UnexpectedEOF;
            }

            if (p.lexer.peek() == .eol) {
                _ = p.lexer.next();
                continue;
            }

            if (try p.parseStatement()) |statement| {
                try block_statements.append(statement);
            }

            const next_tok = p.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = p.lexer.next();
            }
        }

        _ = p.lexer.next();

        const block_stmt = try p.allocator.create(stmt.Statement);

        block_stmt.* = stmt.Statement{ .block = .{
            .statements = block_statements,
            .environment = block_environment,
        } };

        return block_stmt;
    }

    fn parseFunctionDeclaration(p: *Parser) ParseError!*stmt.Statement {
        _ = p.lexer.next();

        const ident_lex = p.lexer.next();
        if (ident_lex != .ident) {
            std.log.err("expected identifier after 'fn' keyword, got {s}", .{@tagName(p.lexer.peek())});
            return error.ExpectedIdentifier;
        }
        const ident = ident_lex.ident;

        if (p.lexer.next() != .lparen) {
            std.log.err("expected '(' after function name, got {s}", .{@tagName(p.lexer.peek())});
            return error.MissingOpeningParenthesis;
        }

        var parameters = std.array_list.Managed([]const u8).init(p.allocator);

        if (p.lexer.peek() != .rparen) {
            while (true) {
                const param_lex = p.lexer.next();

                if (param_lex != .ident) {
                    std.log.err("expected parameter identifier, got {s}", .{@tagName(param_lex)});
                    for (parameters.items) |param_name| {
                        p.allocator.free(param_name);
                    }
                    parameters.deinit();
                    return error.MissingParameter;
                }

                const parameter_name = try p.allocator.dupe(u8, param_lex.ident);
                try parameters.append(parameter_name);

                const next_tok = p.lexer.peek();
                if (next_tok == .rparen) {
                    break;
                } else if (next_tok == .comma) {
                    _ = p.lexer.next();
                    continue;
                } else {
                    std.log.err("expected comma or ')' after parameter, got {s}", .{@tagName(next_tok)});
                    for (parameters.items) |param_name| {
                        p.allocator.free(param_name);
                    }
                    parameters.deinit();
                    return error.MissingComma;
                }
            }
        }

        if (p.lexer.next() != .rparen) {
            std.log.err("expected ')' after parameter list, got {s}", .{@tagName(p.lexer.peek())});
            for (parameters.items) |param_name| {
                p.allocator.free(param_name);
            }
            parameters.deinit();
            return error.MissingClosingParenthesis;
        }

        const block_stmt = try p.parseBlock();

        const block_ptr = try p.allocator.create(stmt.Block);
        errdefer p.allocator.destroy(block_ptr);

        switch (block_stmt.*) {
            .block => |*blk| {
                block_ptr.* = stmt.Block{
                    .statements = blk.statements,
                    .environment = blk.environment,
                };
                blk.statements = std.array_list.Managed(*stmt.Statement).init(p.allocator);
                blk.environment = std.StringHashMap(v.Value).init(p.allocator);
            },
            else => {
                p.allocator.destroy(block_ptr);
                p.allocator.destroy(block_stmt);
                for (parameters.items) |param_name| {
                    p.allocator.free(param_name);
                }
                parameters.deinit();
                return error.ParseError;
            },
        }

        const function_declaration = try p.allocator.create(stmt.Statement);

        function_declaration.* = stmt.Statement{
            .function_declaration = .{
                .name = ident,
                .block = block_ptr,
                .parameters = parameters,
            },
        };

        p.allocator.destroy(block_stmt);

        return function_declaration;
    }

    fn parseReturn(self: *Parser) ParseError!*stmt.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();

        const ret_stmt = try self.allocator.create(stmt.Statement);
        errdefer self.allocator.destroy(ret_stmt);

        ret_stmt.* = .{ .ret = .{
            .value = value,
        } };

        return ret_stmt;
    }

    fn parseIf(self: *Parser) ParseError!*stmt.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();
        const block_stmt = try self.parseBlock();

        const block_ptr = try self.allocator.create(stmt.Block);
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

        const if_stmt = try self.allocator.create(stmt.Statement);
        if_stmt.* = .{ .if_cond = .{ .body = block_ptr, .condition = value } };

        self.allocator.destroy(block_stmt);

        return if_stmt;
    }

    fn parseWhile(self: *Parser) ParseError!*stmt.Statement {
        _ = self.lexer.next();

        const value = try self.parseExpression();
        const block_stmt = try self.parseBlock();

        const block_ptr = try self.allocator.create(stmt.Block);
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

        const while_stmt = try self.allocator.create(stmt.Statement);
        while_stmt.* = .{ .while_loop = .{ .body = block_ptr, .condition = value } };

        self.allocator.destroy(block_stmt);

        return while_stmt;
    }
};
