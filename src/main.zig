const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    var input_buffer: [1024]u8 = undefined;
    var output_buffer: [1024]u8 = undefined;
    const allocator = std.heap.page_allocator;
    const stdin = std.fs.File.stdin();
    const stdout = std.fs.File.stdout();
    var out_writer = stdout.writer(&output_buffer);

    while (true) {
        const input_size = try stdin.read(&input_buffer);

        if (input_size == 0) {
            continue;
        }

        const input = input_buffer[0..input_size];

        const lexer: Lexer = Lexer.init(input);
        var parser: Parser = Parser.init(lexer, allocator);

        var ast = parser.parse_expr() catch {
            try stdout.writeAll("Command does not exist\n");
            continue;
        };

        defer ast.deinit(allocator);

        const value = try ast.eval();

        try out_writer.interface.print("{d}\n", .{value});
        try out_writer.interface.flush();
    }
}
