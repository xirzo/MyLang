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

test "call a function" {
    const src =
        \\ fn test() { }
        \\ test();
    ;

    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();

    try std.testing.expect(program.getFunction("test") != null);
}

// test "get value from a function" {
//     const src =
//         \\ fn test() {
//         \\   return 5;
//         \\ }
//         \\ let x = test();
//     ;
//
//     const lexer: Lexer = Lexer.init(src);
//     var parser: Parser = Parser.init(lexer, std.testing.allocator);
//
//     var program = try parser.parse();
//     defer program.deinit();
//
//     try program.execute();
//
//     const value = program.environment.get("x") orelse {
//         std.debug.print("Variable 'x' not found in environment\n", .{});
//         return error.TestExpectedEqual;
//     };
//
//     try std.testing.expectEqual(value, 5.0);
// }
