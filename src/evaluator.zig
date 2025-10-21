const std = @import("std");
const e = @import("expression.zig");
const ex = @import("executor.zig");
const v = @import("value.zig");
const s = @import("statement.zig");
const prog = @import("program.zig");
const errors = @import("errors.zig");

pub const EvaluationError = errors.EvaluationError;

pub const Evaluator = struct {
    program: *prog.Program,
    environment: *std.StringHashMap(v.Value),
    functions: *std.StringHashMap(*s.FunctionDeclaration),

    pub fn init(program: *prog.Program, environment: *std.StringHashMap(v.Value), functions: *std.StringHashMap(*s.FunctionDeclaration)) Evaluator {
        return Evaluator{
            .program = program,
            .environment = environment,
            .functions = functions,
        };
    }

    pub fn evaluate(self: *Evaluator, expr: *e.Expression) EvaluationError!v.Value {
        return switch (expr.*) {
            .constant => |a| a.value,
            .variable => |vrbl| self.evaluateVariable(vrbl),
            .binary_operator => |o| self.evaluateBinaryOperator(o),
            .function_call => |*function_call| self.evaluateFunctionCall(function_call),
        };
    }

    fn evaluateVariable(self: *Evaluator, vrbl: e.Variable) EvaluationError!v.Value {
        return self.environment.get(vrbl.name) orelse error.UndefinedVariable;
    }

    fn evaluateBinaryOperator(self: *Evaluator, op: e.BinaryOperator) EvaluationError!v.Value {
        const lhs = if (op.lhs) |l| try self.evaluate(l) else {
            return error.NoLeftExpression;
        };

        const rhs = if (op.rhs) |r| try self.evaluate(r) else {
            return error.NoRightExpression;
        };

        return switch (op.value) {
            '+' => try addValues(self.program.allocator, lhs, rhs),
            '-' => try subtractValues(lhs, rhs),
            '*' => try multiplyValues(self.program.allocator, lhs, rhs),
            '/' => try divideValues(lhs, rhs),
            '!' => try factorialValue(lhs),
            else => error.UnsupportedOperator,
        };
    }

    fn addValues(allocator: std.mem.Allocator, lhs: v.Value, rhs: v.Value) EvaluationError!v.Value {
        switch (lhs) {
            .number => |lnum| {
                switch (rhs) {
                    .number => |rnum| return v.Value{ .number = lnum + rnum },
                    .string => |rstr| {
                        var buf: [32]u8 = undefined;
                        const lstr = try std.fmt.bufPrint(&buf, "{d}", .{lnum});
                        const result = try allocator.alloc(u8, lstr.len + rstr.len);
                        @memcpy(result[0..lstr.len], lstr);
                        @memcpy(result[lstr.len..], rstr);
                        return v.Value{ .string = result };
                    },
                    .char => |_| {
                        return error.TypeMismatch;
                    },
                    .none => return lhs,
                }
            },
            .string => |lstr| {
                switch (rhs) {
                    .number => |rnum| {
                        var buf: [32]u8 = undefined;
                        const rstr = try std.fmt.bufPrint(&buf, "{d}", .{rnum});
                        const result = try allocator.alloc(u8, lstr.len + rstr.len);
                        @memcpy(result[0..lstr.len], lstr);
                        @memcpy(result[lstr.len..], rstr);
                        return v.Value{ .string = result };
                    },
                    .string => |rstr| {
                        const result = try allocator.alloc(u8, lstr.len + rstr.len);
                        @memcpy(result[0..lstr.len], lstr);
                        @memcpy(result[lstr.len..], rstr);
                        return v.Value{ .string = result };
                    },
                    .char => |rchar| {
                        const result = try allocator.alloc(u8, lstr.len + 1);
                        @memcpy(result[0..lstr.len], lstr);
                        result[lstr.len] = rchar;
                        return v.Value{ .string = result };
                    },
                    .none => return lhs,
                }
            },
            .char => |lchar| {
                switch (rhs) {
                    .number => |_| {
                        return error.TypeMismatch;
                    },
                    .string => |rstr| {
                        const result = try allocator.alloc(u8, 1 + rstr.len);
                        result[0] = lchar;
                        @memcpy(result[1..], rstr);
                        return v.Value{ .string = result };
                    },
                    .char => |rchar| {
                        const result = try allocator.alloc(u8, 2);
                        result[0] = lchar;
                        result[1] = rchar;
                        return v.Value{ .string = result };
                    },
                    .none => return lhs,
                }
            },
            .none => return rhs,
        }
    }

    fn subtractValues(lhs: v.Value, rhs: v.Value) EvaluationError!v.Value {
        switch (lhs) {
            .number => |lnum| {
                switch (rhs) {
                    .number => |rnum| return v.Value{ .number = lnum - rnum },
                    else => return error.TypeMismatch,
                }
            },
            else => return error.TypeMismatch,
        }
    }

    fn multiplyValues(allocator: std.mem.Allocator, lhs: v.Value, rhs: v.Value) EvaluationError!v.Value {
        switch (lhs) {
            .number => |lnum| {
                switch (rhs) {
                    .number => |rnum| return v.Value{ .number = lnum * rnum },
                    .string => |rstr| {
                        if (lnum < 0 or lnum != @trunc(lnum))
                            return error.InvalidMultiplication;

                        const repeat = @as(usize, @intFromFloat(lnum));

                        if (repeat == 0)
                            return v.Value{ .string = try allocator.alloc(u8, 0) };

                        const result = try allocator.alloc(u8, rstr.len * repeat);
                        var i: usize = 0;
                        while (i < repeat) : (i += 1) {
                            @memcpy(result[i * rstr.len ..][0..rstr.len], rstr);
                        }
                        return v.Value{ .string = result };
                    },
                    else => return error.TypeMismatch,
                }
            },
            .string => |lstr| {
                switch (rhs) {
                    .number => |rnum| {
                        if (rnum < 0 or rnum != @trunc(rnum))
                            return error.InvalidMultiplication;

                        const repeat = @as(usize, @intFromFloat(rnum));

                        if (repeat == 0)
                            return v.Value{ .string = try allocator.alloc(u8, 0) };

                        const result = try allocator.alloc(u8, lstr.len * repeat);

                        var i: usize = 0;

                        while (i < repeat) : (i += 1) {
                            @memcpy(result[i * lstr.len ..][0..lstr.len], lstr);
                        }
                        return v.Value{ .string = result };
                    },
                    else => return error.TypeMismatch,
                }
            },
            else => return error.TypeMismatch,
        }
    }

    fn divideValues(lhs: v.Value, rhs: v.Value) EvaluationError!v.Value {
        switch (lhs) {
            .number => |lnum| {
                switch (rhs) {
                    .number => |rnum| {
                        if (rnum == 0) return error.DivisionByZero;
                        return v.Value{ .number = lnum / rnum };
                    },
                    else => return error.TypeMismatch,
                }
            },
            else => return error.TypeMismatch,
        }
    }

    fn factorialValue(val: v.Value) EvaluationError!v.Value {
        switch (val) {
            .number => |num| {
                if (num < 0 or num != @trunc(num)) return error.InvalidFactorial;

                var result: f64 = 1;
                var i: usize = 2;
                const n = @as(usize, @intFromFloat(num));

                while (i <= n) : (i += 1) {
                    result *= @as(f64, @floatFromInt(i));
                }

                return v.Value{ .number = result };
            },
            else => return error.TypeMismatch,
        }
    }

    fn evaluateFunctionCall(self: *Evaluator, function_call: *e.FunctionCall) EvaluationError!v.Value {
        var iter = self.functions.iterator();

        while (iter.next()) |entry| {
            std.debug.print("Available function: {s}\n", .{entry.key_ptr.*});
        }

        const func = self.functions.get(function_call.function_name) orelse {
            std.log.err("call to undefined function, {s}", .{function_call.function_name});
            return error.UndefinedFunction;
        };

        std.debug.print("Found function: {s}\n", .{func.ident});

        var saved_vars = std.StringHashMap(v.Value).init(self.environment.allocator);
        defer saved_vars.deinit();

        var env_iter = self.environment.iterator();

        while (env_iter.next()) |entry| {
            try saved_vars.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        if (function_call.parameters.items.len > 0 or func.parameters.items.len > 0) {
            if (func.parameters.items.len != function_call.parameters.items.len) {
                std.log.err("Function {s} expects {d} parameters, got {d}", .{ function_call.function_name, func.parameters.items.len, function_call.parameters.items.len });
                return error.UndefinedFunction;
            }

            for (function_call.parameters.items, 0..) |param_expr, i| {
                const param_value = try self.evaluate(param_expr);
                try self.environment.put(func.parameters.items[i], param_value);
            }
        }

        var block_statement = s.Statement{ .block = func.block.* };

        try ex.executeStatement(&block_statement, self.program);

        self.environment.clearRetainingCapacity();
        var saved_iter = saved_vars.iterator();

        while (saved_iter.next()) |entry| {
            try self.environment.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return self.program.ret_value.*;
    }
};

fn factorial(n: v.Value) f64 {
    var i: v.Value = 1;
    var fact: v.Value = 1;

    while (i <= n) {
        fact *= i;
        i += 1;
    }

    return fact;
}
