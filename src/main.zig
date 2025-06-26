const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Lexeme = @import("lexer.zig").Lexeme;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        const buf: []u8 = try allocator.alloc(u8, 1024);
        defer allocator.free(buf);

        if (try stdin.readUntilDelimiterOrEof(buf, '\n')) |input| {
            if (input.len == 0) continue;

            const lexer: Lexer = Lexer.init(input);
            var parser: Parser = Parser.init(lexer, allocator);

            const ast = parser.expr() catch {
                try stdout.print("Command does not exist\n", .{});
                continue;
            };

            defer ast.deinit(allocator);

            const value = try ast.eval();

            try stdout.print("{d}\n", .{value});
        } else {
            break;
        }
    }
}
