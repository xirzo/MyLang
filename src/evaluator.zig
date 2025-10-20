const std = @import("std");
const e = @import("expression.zig");
const s = @import("statement.zig");
const prog = @import("program.zig");

pub const EvaluationError = error{
    UndefinedVariable,
    UndefinedFunction,
    DivisionByZero,
    UnsupportedOperator,
    OutOfMemory,
};

pub const Evaluator = struct {
    environment: *std.StringHashMap(f64),
    functions: *std.StringHashMap(*s.FunctionDeclaration),

    pub fn init(environment: *std.StringHashMap(f64), functions: *std.StringHashMap(*s.FunctionDeclaration)) Evaluator {
        return Evaluator{
            .environment = environment,
            .functions = functions,
        };
    }

    pub fn evaluate(self: *Evaluator, expr: *e.Expression) EvaluationError!f64 {
        return switch (expr.*) {
            .constant => |a| a.value,
            .variable => |vrbl| self.evaluateVariable(vrbl),
            .binary_operator => |o| self.evaluateBinaryOperator(o),
            // .function_call => |function_call| self.evaluateFunctionCall(function_call),
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

    // fn evaluateFunctionCall(self: *Evaluator, function_call: e.FunctionCall) EvaluationError!f64 {}
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
