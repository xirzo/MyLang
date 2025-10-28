const std = @import("std");
const s = @import("statement.zig");
const v = @import("value.zig");

pub const Constant = union(enum) {
    number: f64,
    string: []const u8,
    char: u8,
    boolean: bool,
    array: std.array_list.Managed(*Expression),

    pub fn deinit(self: *Constant, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => |*arr| {
                for (arr.items) |el| {
                    el.deinit(allocator);
                    allocator.destroy(el);
                }
                arr.deinit();
            },
            else => {},
        }
    }
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

    pub fn deinit(self: *FunctionCall, allocator: std.mem.Allocator) void {
        for (self.parameters.items) |param| {
            param.deinit(allocator);
            allocator.destroy(param);
        }
        self.parameters.deinit();
    }
};

pub const ComparisonOperator = struct {
    lhs: *Expression,
    rhs: *Expression,
    op: []const u8,
};

pub const Expression = union(enum) {
    constant: Constant,
    variable: Variable,
    binary_operator: BinaryOperator,
    function_call: FunctionCall,
    comparison_operator: ComparisonOperator,

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .constant => |*constant| constant.deinit(allocator),
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
            .function_call => |*function_call| function_call.deinit(allocator),
            .comparison_operator => |*comp_op| {
                comp_op.lhs.deinit(allocator);
                allocator.destroy(comp_op.lhs);
                comp_op.rhs.deinit(allocator);
                allocator.destroy(comp_op.rhs);
            },
        }
    }
};
