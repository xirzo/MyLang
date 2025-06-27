const std = @import("std");
const Lexeme = @import("lexer.zig").Lexeme;

pub const Atom = struct {
    value: i64,
};

pub const Op = struct {
    value: u8,
    lhs: ?*Ast,
    rhs: ?*Ast,
};

fn factorial(n: i64) i64 {
    var i: i64 = 1;
    var fact: i64 = 1;

    while (i <= n) {
        fact *= i;
        i += 1;
    }

    return fact;
}

pub const Ast = union(enum) {
    atom: Atom,
    op: Op,

    pub fn deinit(self: *Ast, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .atom => {},
            .op => |*op| {
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

    pub fn eval(self: *Ast) !i64 {
        return switch (self.*) {
            .atom => |a| a.value,
            .op => |o| blk: {
                const lhs = if (o.lhs) |l| try l.eval() else 0;
                const rhs = if (o.rhs) |r| try r.eval() else 0;
                break :blk switch (o.value) {
                    '+' => lhs + rhs,
                    '-' => lhs - rhs,
                    '*' => lhs * rhs,
                    '/' => if (rhs == 0) error.DivisionByZero else @divTrunc(lhs, rhs),
                    '!' => factorial(lhs),
                    else => error.UnsupportedOperator,
                };
            },
        };
    }
};
