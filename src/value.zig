const std = @import("std");

pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    char: u8,
    boolean: bool,
    array: std.array_list.Managed(Value),
    none: void,

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit();
            },
            .string => |str| {
                if (str.len > 0) {
                    allocator.free(str);
                }
            },
            else => {},
        }
    }
};
