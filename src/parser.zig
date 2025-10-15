const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Expression = @import("expression.zig").Expression;
const Statement = @import("statement.zig").Statement;
const Program = @import("statement.zig").Program;
const assert = std.debug.assert;
const BinaryOperator = @import("expression.zig").BinaryOperator;

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,

    pub fn init(l: Lexer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .lexer = l,
            .allocator = allocator,
        };
    }

    pub fn parse(p: *Parser) !Program {
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

    fn expression(p: *Parser, min_bp: u8) !*Expression {
        const lex: Lexeme = p.lexer.next();

        var lhs: *Expression = switch (lex) {
            .number => |num| blk: {
                const expr_node: *Expression = try p.allocator.create(Expression);
                expr_node.* = Expression{ .constant = .{ .value = num } };
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
                    return error.ParseError;
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

    pub fn parseStatement(p: *Parser) !?*Statement {
        const tok = p.lexer.peek();

        return switch (tok) {
            .let => blk: {
                _ = p.lexer.next();
                break :blk try p.parseLetStatement();
            },
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

    fn parseLetStatement(p: *Parser) !*Statement {
        const ident_lex = p.lexer.next();

        if (ident_lex != .ident) {
            std.log.err("expected identifier after 'let', got {any}", .{ident_lex});
            return error.ParseError;
        }

        const var_name = ident_lex.ident;
        const name_copy = try p.allocator.dupe(u8, var_name);
        const equal_lex = p.lexer.next();

        if (equal_lex != .assign) {
            std.log.err("expected '=' after variable name, got {any}", .{equal_lex});
            p.allocator.free(name_copy);
            return error.ParseError;
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
};
