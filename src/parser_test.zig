const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;
const a = @import("ast.zig");

// test "parse assignment" {
//     const src = "int a = 5;";
//     const lexer: Lexer = Lexer.init(src);
//     var parser: Parser = Parser.init(lexer);
//
//     parser.parse();
// }

test "parse single digit number" {
    const src = "5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.parse_expr();
    defer ast.deinit(std.testing.allocator);

    try std.testing.expectEqual(5, ast.atom.value);
}

test "parse infix operator" {
    const src = "5 + 5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.parse_expr();
    defer ast.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u8, '+'), ast.op.value);
    try std.testing.expectEqual(@as(i64, 5), ast.op.lhs.?.*.atom.value);
    try std.testing.expectEqual(@as(i64, 5), ast.op.rhs.?.*.atom.value);
}

test "parse prefix minus" {
    const src = "-5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.parse_expr();
    defer ast.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u8, '-'), ast.op.value);
    try std.testing.expect(ast.op.lhs == null);
    try std.testing.expectEqual(@as(i64, 5), ast.op.rhs.?.*.atom.value);
}

test "parse double prefix minus" {
    const src = "--5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.parse_expr();
    defer ast.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u8, '-'), ast.op.value);
    try std.testing.expect(ast.op.lhs == null);

    const inner_ptr = ast.op.rhs.?;
    const inner = inner_ptr.*;
    try std.testing.expectEqual(@as(u8, '-'), inner.op.value);
    try std.testing.expect(inner.op.lhs == null);

    const atom_ptr = inner.op.rhs.?;
    const atom = atom_ptr.*;
    try std.testing.expectEqual(@as(i64, 5), atom.atom.value);
}
