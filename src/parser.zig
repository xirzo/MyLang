const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Ast = @import("ast.zig").Ast;
const Op = @import("ast.zig").Op;

pub const Parser = struct {
    l: Lexer,
    allocator: std.mem.Allocator,

    pub fn init(l: Lexer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .l = l,
            .allocator = allocator,
        };
    }

    pub fn parse_expr(p: *Parser) !Ast {
        // std.debug.print("expr call\n", .{});
        return try p.expr(0);
    }

    fn prefix_binding_power(op: u8) ?u8 {
        return switch (op) {
            '+', '-' => 5,
            else => null,
        };
    }

    fn infix_binding_power(op: u8) ?struct { u8, u8 } {
        return switch (op) {
            '+', '-' => .{ 1, 2 },
            '*', '/' => .{ 3, 4 },
            else => null,
        };
    }

    fn expr(p: *Parser, min_bp: u8) !Ast {
        const lex: Lexeme = p.l.next();

        // std.debug.print("expr binary call with token {any}\n", .{@as(std.meta.Tag(Lexeme), lex)});

        var lhs: Ast = switch (lex) {
            .number => |num| Ast{ .atom = .{ .value = num } },
            else => blk: {
                if (lex.get_binary_oper_char()) |char| {
                    if (prefix_binding_power(char)) |r_bp| {
                        const rhs = try p.expr(r_bp);
                        const rhs_node = try p.allocator.create(Ast);
                        rhs_node.* = rhs;
                        break :blk Ast{ .op = .{ .lhs = null, .rhs = rhs_node, .value = char } };
                    } else {
                        std.log.err("operator cannot be used as prefix {any}\n", .{@as(std.meta.Tag(Lexeme), lex)});
                        unreachable;
                    }
                } else {
                    std.log.err("bad lexeme for binary expression parse {any}\n", .{@as(std.meta.Tag(Lexeme), lex)});
                    unreachable;
                }
            },
        };

        while (true) {
            const oper_lex: Lexeme = p.l.peek();

            const oper_char: u8 = switch (oper_lex) {
                .eof => break,
                else => blk: {
                    if (oper_lex.get_binary_oper_char()) |char| {
                        break :blk char;
                    }

                    std.debug.print("not binary operator: {any}\n", .{@as(std.meta.Tag(Lexeme), oper_lex)});
                    // not binary operator
                    unreachable;
                },
            };

            const bp = infix_binding_power(oper_char) orelse .{ 0, 0 };

            const l_bp = bp[0];
            const r_bp = bp[1];

            if (min_bp > l_bp) {
                break;
            }

            _ = p.l.next();

            const rhs = try expr(p, r_bp);

            const lhs_node = try p.allocator.create(Ast);
            lhs_node.* = lhs;
            const rhs_node = try p.allocator.create(Ast);
            rhs_node.* = rhs;

            lhs = .{ .op = .{
                .value = oper_char,
                .lhs = lhs_node,
                .rhs = rhs_node,
            } };
        }

        return lhs;
    }
};
