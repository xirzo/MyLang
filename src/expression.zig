const std = @import("std");

pub const Constant = struct {
    value: f64,
};

pub const BinaryOperator = struct {
    value: u8,
    lhs: ?*Expression,
    rhs: ?*Expression,
};

pub const Variable = struct {
    name: []const u8,
};

pub const Expression = union(enum) {
    constant: Constant,
    variable: Variable,
    binary_operator: BinaryOperator,

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .constant => {},
            .variable => |*vrbl| {
                allocator.free(vrbl.name);
            },
            .binary_operator => |*op| {
                if (op.lhs) |lhs| {
                    lhs.deinit(allocator);
                    allocator.destroy(lhs);
                }
                if (op.rhs) |rhs| {
                    rhs.deinit(allocator);
                    allocator.destroy(rhs);
                }
            },
        }
    }
};
