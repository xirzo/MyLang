const std = @import("std");
const Lexeme = @import("lexer.zig").Lexeme;

pub const Atom = struct {
    value: i64,
};

pub const Op = struct {
    value: u8,
    lhs: *Ast,
    rhs: *Ast,
};

pub const Ast = union(enum) {
    atom: Atom,
    op: Op,

    pub fn deinit(self: Ast, allocator: std.mem.Allocator) void {
        switch (self) {
            .atom => {},
            .op => |op| {
                op.lhs.deinit(allocator);
                op.rhs.deinit(allocator);
                allocator.destroy(op.lhs);
                allocator.destroy(op.rhs);
            },
        }
    }

    pub fn eval(self: Ast) !i64 {
        return switch (self) {
            .atom => |a| a.value,
            .op => |o| {
                const lhs = try o.lhs.eval();
                const rhs = try o.rhs.eval();

                return switch (o.value) {
                    '+' => lhs + rhs,
                    '-' => lhs - rhs,
                    '*' => lhs * rhs,
                    '/' => if (rhs == 0) error.DivisionByZero else @divTrunc(lhs, rhs),
                    else => error.UnsupportedOperator,
                };
            },
        };
    }
};
