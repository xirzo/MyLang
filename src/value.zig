const std = @import("std");

pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    char: u8,
    boolean: bool,
    array: std.array_list.Managed(Value),
    none: void,
    object: std.array_list.Managed(Value),

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => {
                for (self.array.items) |*item| {
                    item.deinit(allocator);
                }
                self.array.deinit();
            },
            .string => |str| {
                if (str.len > 0) {
                    allocator.free(str);
                }
            },
            .object => {
                for (self.object.items) |*item| {
                    item.deinit(allocator);
                }
                self.object.deinit();
            },
            else => {},
        }
    }
};
