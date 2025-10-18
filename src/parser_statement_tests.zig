const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

test "assign number to a variable" {
    const src = "let x = 5;";
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();

    const value = program.environment.get("x") orelse {
        std.debug.print("Variable 'x' not found in environment\n", .{});
        return error.TestExpectedEqual;
    };

    try std.testing.expect(value == 5.0);
}

test "assign vartiable value to a variable" {
    const src =
        \\let x = 5;
        \\let y = x + 1;
    ;
    const lexer: Lexer = Lexer.init(src);
    var parser: Parser = Parser.init(lexer, std.testing.allocator);

    var program = try parser.parse();
    defer program.deinit();

    try program.execute();

    const value = program.environment.get("y") orelse {
        std.debug.print("Variable 'y' not found in environment\n", .{});
        return error.TestExpectedEqual;
    };

    try std.testing.expect(value == 6.0);
}
