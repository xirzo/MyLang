const std = @import("std");
const e = @import("expression.zig");
const ex = @import("executor.zig");
const s = @import("statement.zig");
const prog = @import("program.zig");
const errors = @import("errors.zig");

pub const EvaluationError = errors.EvaluationError;

pub const Evaluator = struct {
    program: *prog.Program,
    environment: *std.StringHashMap(f64),
    functions: *std.StringHashMap(*s.FunctionDeclaration),

    pub fn init(program: *prog.Program, environment: *std.StringHashMap(f64), functions: *std.StringHashMap(*s.FunctionDeclaration)) Evaluator {
        return Evaluator{
            .program = program,
            .environment = environment,
            .functions = functions,
        };
    }

    pub fn evaluate(self: *Evaluator, expr: *e.Expression) EvaluationError!f64 {
        return switch (expr.*) {
            .constant => |a| a.value,
            .variable => |vrbl| self.evaluateVariable(vrbl),
            .binary_operator => |o| self.evaluateBinaryOperator(o),
            .function_call => |*function_call| self.evaluateFunctionCall(function_call),
        };
    }

    fn evaluateVariable(self: *Evaluator, vrbl: e.Variable) EvaluationError!f64 {
        return self.environment.get(vrbl.name) orelse error.UndefinedVariable;
    }

    fn evaluateBinaryOperator(self: *Evaluator, op: e.BinaryOperator) EvaluationError!f64 {
        const lhs = if (op.lhs) |l| try self.evaluate(l) else 0;
        const rhs = if (op.rhs) |r| try self.evaluate(r) else 0;

        return switch (op.value) {
            '+' => lhs + rhs,
            '-' => lhs - rhs,
            '*' => lhs * rhs,
            '/' => if (rhs == 0) error.DivisionByZero else lhs / rhs,
            '!' => factorial(lhs),
            else => error.UnsupportedOperator,
        };
    }

    fn evaluateFunctionCall(self: *Evaluator, function_call: *e.FunctionCall) EvaluationError!f64 {
        var iter = self.functions.iterator();

        while (iter.next()) |entry| {
            std.debug.print("Available function: {s}\n", .{entry.key_ptr.*});
        }

        const func = self.functions.get(function_call.function_name) orelse {
            std.log.err("call to undefined function, {s}", .{function_call.function_name});
            return error.UndefinedFunction;
        };

        std.debug.print("Found function: {s}\n", .{func.ident});

        var saved_vars = std.StringHashMap(f64).init(self.environment.allocator);
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

        const return_value = if (self.program.ret_value) |ret_val| ret_val.* else 0.0;

        self.environment.clearRetainingCapacity();
        var saved_iter = saved_vars.iterator();

        while (saved_iter.next()) |entry| {
            try self.environment.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return return_value;
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
