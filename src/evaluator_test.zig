const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

test "evaluate arithmetic expression" {
    const src = "5 + 5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.expr();
    defer ast.deinit(std.testing.allocator);

    const result = try ast.eval();
    try std.testing.expectEqual(@as(i64, 10), result);
}

test "evaluate complex arithmetic expression" {
    const src = "5 + 5 * 2";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var ast = try parser.expr();
    defer ast.deinit(std.testing.allocator);

    const result = try ast.eval();
    try std.testing.expectEqual(@as(i64, 15), result);
}
