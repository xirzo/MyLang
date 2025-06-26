const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

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

    const ast = try parser.expr();

    try std.testing.expectEqual(5, ast.atom.value);
}

test "parse infix operator" {
    const src = "5 + 5";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    _ = try parser.expr();
}
