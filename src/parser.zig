const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Ast = @import("ast.zig").Ast;

pub const Parser = struct {
    l: Lexer,

    pub fn init(l: Lexer) Parser {
        return Parser{
            .l = l,
        };
    }

    pub fn expr(p: *Parser) Ast {
        return p.expr_binary();
    }

    fn expr_binary(p: *Parser) Ast {
        const lex: Lexeme = p.l.next();

        const lhs = switch (lex) {
            .number => |num| Ast{ .atom = .{ .value = num } },
            else => {
                std.log.err("bad lexeme for binary expression parse {any}\n", .{@as(std.meta.Tag(Lexeme), lex)});
                unreachable;
            },
        };

        return lhs;
    }

    // pub fn parse(p: *Parser) void {
    //     const peeked: Lexeme = p.l.peek();
    //     while (peeked != .eof) {
    //         switch (peeked) {
    //             .illegal => @panic("ILLEGAL token"),
    //             .ident => blk: {
    //                 break :blk;
    //             },
    //             .assign => blk: {
    //                 break :blk;
    //             },
    //             .number => blk: {
    //                 break :blk;
    //             },
    //             .semicolon => blk: {
    //                 break :blk;
    //             },
    //             .eof => blk: {
    //                 break :blk;
    //             },
    //         }
    //     }
    // }
};
