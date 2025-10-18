const std = @import("std");
const s = @import("statement.zig");

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

pub const FunctionCall = struct {
    function_name: []const u8,
    parameters: std.array_list.Managed(*Expression),
    declaration: *s.FunctionDeclaration,
};

pub const Expression = union(enum) {
    constant: Constant,
    variable: Variable,
    binary_operator: BinaryOperator,
    // function_call: FunctionCall,

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
            // .function_call => |*function_call| {
            //     function_call.parameters.deinit();
            //     allocator.free(function_call.function_name);
            // },
        }
    }
};
