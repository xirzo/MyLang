const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

test "declare a function" {
    const src =
        \\ fn test() { }
    ;

    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();

    try std.testing.expect(program.getFunction("test") != null);
}
