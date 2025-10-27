const std = @import("std");

pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    char: u8,
    boolean: bool,
    array: std.array_list.Managed(Value),
    none: void,
};
