const std = @import("std");
const mylang = @import("mylang");

pub fn main() !void {
    var stdout = std.fs.File.stdout();
    var output_buffer: [1024]u8 = undefined;
    var out_writer = stdout.writer(&output_buffer);

    const allocator = std.heap.page_allocator;

    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    const program_name = arg_iterator.next();

    const path = arg_iterator.next() orelse {
        try out_writer.interface.print("Usage: {s} <path>\n", .{program_name.?});
        try out_writer.interface.flush();
        return;
    };

    const file = try std.fs.Dir.openFile(std.fs.cwd(), path, .{ .mode = .read_only });
    defer file.close();

    var input_buffer: [1024]u8 = undefined;
    var reader = file.reader(&input_buffer);

    reader.interface.readSliceAll(&input_buffer) catch |err| switch (err) {
        error.ReadFailed => unreachable,
        error.EndOfStream => {},
    };

    const program = try mylang.createInterpreter(allocator, &input_buffer);
    defer program.deinit();

    try program.execute();
}
