const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;

pub fn main() void {
    const src = "var_name";
    const lexer: Lexer = Lexer.init(src);

    std.debug.print("{s}\n", .{lexer.src});
}
