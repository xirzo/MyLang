const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;

test "lex assignment" {
    const src = "int a = 5;";
    var lexer: Lexer = Lexer.init(src);

    var expected = std.ArrayList(Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(Lexeme{ .ident = "int" });
    try expected.append(Lexeme{ .ident = "a" });
    try expected.append(Lexeme{ .assign = '=' });
    try expected.append(Lexeme{ .number = 5 });
    try expected.append(Lexeme{ .semicolon = ';' });
    try expected.append(Lexeme{ .eof = 0 });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        std.debug.print("{any}, {any}\n", .{ @as(std.meta.Tag(Lexeme), exp_token), @as(std.meta.Tag(Lexeme), actual_token) });

        try std.testing.expectEqual(@as(std.meta.Tag(Lexeme), exp_token), @as(std.meta.Tag(Lexeme), actual_token));
    }
}
