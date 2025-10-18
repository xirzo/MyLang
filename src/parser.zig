const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Expression = @import("expression.zig").Expression;
const Statement = @import("statement.zig").Statement;
const Program = @import("statement.zig").Program;
const assert = std.debug.assert;
const BinaryOperator = @import("expression.zig").BinaryOperator;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    MissingClosingBrace,
    MissingOpeningBrace,
    MissingClosingParenthesis,
    MissingOpeningParenthesis,

    InvalidPrefixOperator,
    InvalidInfixOperator,
    InvalidPostfixOperator,
    BadExpressionLexeme,

    ExpectedIdentifier,
    ExpectedAssignment,
    ExpectedSemicolon,

    OutOfMemory,

    ParseError,
};

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,

    pub fn init(l: Lexer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .lexer = l,
            .allocator = allocator,
        };
    }

    pub fn parse(p: *Parser) ParseError!Program {
        var program = Program.init(p.allocator);

        while (true) {
            const tok = p.lexer.peek();

            if (tok == .eof) {
                break;
            }

            if (tok == .eol) {
                _ = p.lexer.next();
                continue;
            }

            if (try p.parseStatement()) |stmt| {
                std.debug.print("Parsed statement\n", .{});
                try program.statements.append(stmt);
            } else {
                _ = p.lexer.next();
            }

            const next_tok = p.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = p.lexer.next();
            }
        }

        return program;
    }

    pub fn parseExpression(p: *Parser) !*Expression {
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

    fn postfixBindingPower(op: u8) ?u8 {
        return switch (op) {
            '!' => 7,
            else => null,
        };
    }

    fn expression(p: *Parser, min_bp: u8) ParseError!*Expression {
        const lex: Lexeme = p.lexer.next();

        var lhs: *Expression = switch (lex) {
            .number => |num| blk: {
                const expr_node: *Expression = try p.allocator.create(Expression);
                expr_node.* = Expression{ .constant = .{ .value = num } };
                break :blk expr_node;
            },
            .ident => |name| blk: {
                const name_copy = try p.allocator.dupe(u8, name);
                const expr_node: *Expression = try p.allocator.create(Expression);
                expr_node.* = Expression{ .variable = .{ .name = name_copy } };
                break :blk expr_node;
            },
            .lparen => blk: {
                const lhs_expr = try p.expression(0);
                assert(p.lexer.next() == .rparen);
                break :blk lhs_expr;
            },
            else => blk: {
                if (lex.getOperatorChar()) |char| {
                    if (prefixBindingPower(char)) |r_bp| {
                        const rhs = try p.expression(r_bp);
                        const expr_node = try p.allocator.create(Expression);
                        expr_node.* = Expression{ .binary_operator = .{ .lhs = null, .rhs = rhs, .value = char } };
                        break :blk expr_node;
                    } else {
                        std.log.err("operator cannot be used as prefix {any}\n", .{lex});
                        return error.ParseError;
                    }
                } else {
                    std.log.err("bad lexeme for expression parse {any}\n", .{lex});
                    return error.BadExpressionLexeme;
                }
            },
        };

        while (true) {
            const oper_lex: Lexeme = p.lexer.peek();

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

                const new_lhs = try p.allocator.create(Expression);
                new_lhs.* = Expression{ .binary_operator = .{ .lhs = lhs, .rhs = null, .value = oper_char } };
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

                const new_lhs = try p.allocator.create(Expression);
                new_lhs.* = Expression{
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

    pub fn parseStatement(p: *Parser) ParseError!?*Statement {
        const tok = p.lexer.peek();

        return switch (tok) {
            .let => blk: {
                // TODO: move p.lexer.next() into parseLet
                _ = p.lexer.next();
                break :blk try p.parseLet();
            },
            .lbrace => try p.parseBlock(),
            else => blk: {
                if (tok == .semicolon or tok == .eol or tok == .eof) {
                    return null;
                }

                const expr_node = try p.parseExpression();
                const stmt_node = try p.allocator.create(Statement);
                stmt_node.* = Statement{ .expression = .{ .expression = expr_node } };
                break :blk stmt_node;
            },
        };
    }

    fn parseLet(p: *Parser) ParseError!*Statement {
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

        const let_stmt = try p.allocator.create(Statement);

        let_stmt.* = Statement{
            .let = .{
                .name = name_copy,
                .value = value,
            },
        };

        return let_stmt;
    }

    pub fn parseBlock(p: *Parser) ParseError!*Statement {
        if (p.lexer.peek() != .lbrace) {
            std.log.err("expected '{{' at start of block, got {s}", .{@tagName(p.lexer.peek())});
            return error.MissingOpeningBrace;
        }

        _ = p.lexer.next();

        var block_statements = std.array_list.Managed(*Statement).init(p.allocator);
        var block_environment = std.StringHashMap(f64).init(p.allocator);

        errdefer {
            for (block_statements.items) |stmt| {
                stmt.deinit(p.allocator);
                p.allocator.destroy(stmt);
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

            if (try p.parseStatement()) |stmt| {
                try block_statements.append(stmt);
            }

            const next_tok = p.lexer.peek();

            if (next_tok == .semicolon or next_tok == .eol) {
                _ = p.lexer.next();
            }
        }

        _ = p.lexer.next();

        const block_stmt = try p.allocator.create(Statement);

        block_stmt.* = Statement{ .block = .{
            .statements = block_statements,
            .environment = block_environment,
        } };

        return block_stmt;
    }
};
