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
    const environment = try allocator.create(std.StringHashMap(f64));

    while (true) {
        const input_size = try stdin.read(&input_buffer);

        if (input_size == 0) {
            continue;
        }

        const input = input_buffer[0..input_size];

        const lexer: Lexer = Lexer.init(input);
        var parser: Parser = Parser.init(lexer, allocator);

        const expression = parser.parseExpression() catch {
            try stdout.writeAll("Command does not exist\n");
            continue;
        };

        defer expression.deinit(allocator);

        const value = try expression.eval(environment);

        try out_writer.interface.print("{d:.02}\n", .{value});
        try out_writer.interface.flush();
    }

    // const allocator = std.heap.page_allocator;
    // const input = "let a = 5 + 5;";
    //
    // const lexer: Lexer = Lexer.init(input);
    // var parser: Parser = Parser.init(lexer, allocator);
    //
    // _ = parser.parse() catch {
    //     // try stdout.writeAll("Command does not exist\n");
    //     // continue;
    // };
}
