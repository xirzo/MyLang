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
            .constant => |constant| self.evaluateConstant(constant),
            .variable => |vrbl| self.evaluateVariable(vrbl),
            .binary_operator => |o| self.evaluateBinaryOperator(o),
            .function_call => |*function_call| self.evaluateFunctionCall(function_call),
            .comparison_operator => |*comp| self.evaluateComparison(comp.*),
        };
    }

    fn evaluateConstant(self: *Evaluator, constant: e.Constant) EvaluationError!v.Value {
        return switch (constant) {
            .number => |num| v.Value{ .number = num },
            .string => |str| v.Value{ .string = str },
            .char => |ch| v.Value{ .char = ch },
            .boolean => |b| v.Value{ .boolean = b },
            .array => |arr| self.evaluateArray(arr),
        };
    }

    fn evaluateArray(self: *Evaluator, arr: std.array_list.Managed(*e.Expression)) EvaluationError!v.Value {
        var elements = std.array_list.Managed(v.Value).init(self.environment.allocator);

        for (arr.items) |el| {
            try elements.append(try self.evaluate(el));
        }

        return v.Value{ .array = elements };
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
            '[' => try indexArray(lhs, rhs),
            else => error.UnsupportedOperator,
        };
    }

    fn evaluateFunctionCall(self: *Evaluator, function_call: *e.FunctionCall) EvaluationError!v.Value {
        if (self.program.builtins.get(function_call.function_name)) |builtin_ptr| {
            const builtin = builtin_ptr.*;
            var args = std.array_list.Managed(v.Value).init(self.program.allocator);
            defer args.deinit();

            for (function_call.parameters.items) |param_expr| {
                const param_value = try self.evaluate(param_expr);
                try args.append(param_value);
            }

            self.program.should_return = false;
            return builtin.executor(self.program, args.items);
        }

        const func = self.functions.get(function_call.function_name) orelse {
            std.log.err("call to undefined function, {s}", .{function_call.function_name});
            return error.UndefinedFunction;
        };

        if (func.parameters.items.len != function_call.parameters.items.len) {
            std.log.err("Function {s} expects {d} parameters, got {d}", .{ function_call.function_name, func.parameters.items.len, function_call.parameters.items.len });
            return error.UndefinedFunction;
        }

        var param_values = std.array_list.Managed(v.Value).init(self.environment.allocator);
        defer param_values.deinit();

        for (function_call.parameters.items) |param_expr| {
            const param_value = try self.evaluate(param_expr);
            try param_values.append(param_value);
        }

        var saved_vars = std.StringHashMap(v.Value).init(self.environment.allocator);
        defer saved_vars.deinit();

        var env_iter = self.environment.iterator();
        while (env_iter.next()) |entry| {
            try saved_vars.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        self.environment.clearRetainingCapacity();
        for (param_values.items, 0..) |param_value, i| {
            try self.environment.put(func.parameters.items[i], param_value);
        }

        const saved_ret_value = self.program.ret_value.*;
        self.program.ret_value.* = v.Value{ .none = {} };
        self.program.should_return = false;

        try ex.executeBlock(func.block, self.program);

        const return_value = self.program.ret_value.*;

        self.environment.clearRetainingCapacity();
        var saved_iter = saved_vars.iterator();
        while (saved_iter.next()) |entry| {
            try self.environment.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        self.program.ret_value.* = saved_ret_value;

        return return_value;
    }

    fn evaluateComparison(self: *Evaluator, comp: e.ComparisonOperator) EvaluationError!v.Value {
        const lhs = try self.evaluate(comp.lhs);
        const rhs = try self.evaluate(comp.rhs);

        return compareValues(lhs, rhs, comp.op);
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
                .boolean => |_| {
                    return error.TypeMismatch;
                },
                .array => |_| {
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
                .boolean => |rbool| {
                    const rstr = if (rbool) "true" else "false";
                    const result = try allocator.alloc(u8, lstr.len + rstr.len);
                    @memcpy(result[0..lstr.len], lstr);
                    @memcpy(result[lstr.len..], rstr);
                    return v.Value{ .string = result };
                },
                .array => |_| {
                    return error.TypeMismatch;
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
                .boolean => |_| {
                    return error.TypeMismatch;
                },
                .array => |_| {
                    return error.TypeMismatch;
                },
                .none => return lhs,
            }
        },
        .boolean => |lbool| {
            switch (rhs) {
                .number => |_| {
                    return error.TypeMismatch;
                },
                .string => |rstr| {
                    const lstr = if (lbool) "true" else "false";
                    const result = try allocator.alloc(u8, lstr.len + rstr.len);
                    @memcpy(result[0..lstr.len], lstr);
                    @memcpy(result[lstr.len..], rstr);
                    return v.Value{ .string = result };
                },
                .char => |_| {
                    return error.TypeMismatch;
                },
                .boolean => |_| {
                    return error.TypeMismatch;
                },
                .array => |_| {
                    return error.TypeMismatch;
                },
                .none => return lhs,
            }
        },
        .array => |larr| {
            switch (rhs) {
                .number => |_| {
                    return error.TypeMismatch;
                },
                .string => |_| {
                    return error.TypeMismatch;
                },
                .char => |_| {
                    return error.TypeMismatch;
                },
                .boolean => |_| {
                    return error.TypeMismatch;
                },
                .array => |rarr| {
                    // NOTE: is this how you do that?
                    const result = try allocator.alloc(v.Value, larr.items.len + rarr.items.len);
                    @memcpy(result[0..larr.items.len], larr.items.ptr);
                    @memcpy(result[larr.items.len..], rarr.items.ptr);
                    return v.Value{ .array = larr };
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

fn compareValues(lhs: v.Value, rhs: v.Value, op: []const u8) EvaluationError!v.Value {
    const result = switch (lhs) {
        .number => |lnum| blk: {
            const rnum = switch (rhs) {
                .number => |n| n,
                else => return error.TypeMismatch,
            };

            // std.debug.print("{d} {s} {d}, {}\n", .{ lnum, op, rnum, lnum <= rnum });

            break :blk if (std.mem.eql(u8, op, "=="))
                lnum == rnum
            else if (std.mem.eql(u8, op, "!="))
                lnum != rnum
            else if (std.mem.eql(u8, op, ">"))
                lnum > rnum
            else if (std.mem.eql(u8, op, ">="))
                lnum >= rnum
            else if (std.mem.eql(u8, op, "<"))
                lnum < rnum
            else if (std.mem.eql(u8, op, "<="))
                lnum <= rnum
            else
                return error.UnsupportedOperator;
        },
        .string => |lstr| blk: {
            const rstr = switch (rhs) {
                .string => |ss| ss,
                else => return error.TypeMismatch,
            };

            const cmp = std.mem.order(u8, lstr, rstr);

            break :blk if (std.mem.eql(u8, op, "=="))
                cmp == .eq
            else if (std.mem.eql(u8, op, "!="))
                cmp != .eq
            else if (std.mem.eql(u8, op, ">"))
                cmp == .gt
            else if (std.mem.eql(u8, op, ">="))
                cmp != .lt
            else if (std.mem.eql(u8, op, "<"))
                cmp == .lt
            else if (std.mem.eql(u8, op, "<="))
                cmp != .gt
            else
                return error.UnsupportedOperator;
        },
        .boolean => |lbool| blk: {
            const rbool = switch (rhs) {
                .boolean => |b| b,
                else => return error.TypeMismatch,
            };

            break :blk if (std.mem.eql(u8, op, "=="))
                lbool == rbool
            else if (std.mem.eql(u8, op, "!="))
                lbool != rbool
            else
                return error.UnsupportedOperator;
        },
        else => return error.TypeMismatch,
    };

    return v.Value{ .boolean = result };
}

fn indexArray(array_val: v.Value, index_val: v.Value) EvaluationError!v.Value {
    const array = switch (array_val) {
        .array => |arr| arr,
        else => return error.TypeMismatch,
    };

    const index = switch (index_val) {
        .number => |num| blk: {
            if (num < 0 or num != @trunc(num)) {
                return error.InvalidIndex;
            }

            break :blk @as(usize, @intFromFloat(num));
        },
        else => return error.TypeMismatch,
    };

    if (index >= array.items.len) {
        return error.IndexOutOfBounds;
    }

    return array.items[index];
}
