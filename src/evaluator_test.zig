const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

test "evaluate arithmetic program" {
    const src = "5 + 5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(@as(f64, 10), result);
}

test "evaluate complex arithmetic program" {
    const src = "5 + 5 * 2";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(@as(f64, 15), result);
}

test "evaluate parentheses program" {
    const src = "(5 + 5) * 2";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parseExpression();
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(@as(f64, 20), result);
}

test "evaluate substraction" {
    const src = "0 - 5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parseExpression();
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(@as(f64, -5), result);
}
