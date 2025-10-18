const std = @import("std");

pub const EvaluationError = error{
    UndefinedVariable,
    DivisionByZero,
    UnsupportedOperator,
    OutOfMemory,
};

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

    pub fn evaluate(self: *Expression, env: *std.StringHashMap(f64)) EvaluationError!f64 {
        return switch (self.*) {
            .constant => |a| a.value,
            .variable => |vrbl| env.get(vrbl.name) orelse error.UndefinedVariable,
            .binary_operator => |o| blk: {
                const lhs = if (o.lhs) |l| try l.evaluate(env) else 0;
                const rhs = if (o.rhs) |r| try r.evaluate(env) else 0;
                break :blk switch (o.value) {
                    '+' => lhs + rhs,
                    '-' => lhs - rhs,
                    '*' => lhs * rhs,
                    '/' => if (rhs == 0) error.DivisionByZero else lhs / rhs,
                    '!' => factorial(lhs),
                    else => error.UnsupportedOperator,
                };
            },
        };
    }
};

fn factorial(n: f64) f64 {
    var i: f64 = 1;
    var fact: f64 = 1;

    while (i <= n) {
        fact *= i;
        i += 1;
    }

    return fact;
}
