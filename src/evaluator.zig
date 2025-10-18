const std = @import("std");
const e = @import("expression.zig");
const s = @import("statement.zig");
const prog = @import("program.zig");
const ex = @import("executor.zig");

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

    fn evaluateFunctionCall(self: *Evaluator, function_call: e.FunctionCall) EvaluationError!f64 {
        const function = self.functions.get(function_call.function_name) orelse {
            return error.UndefinedFunction;
        };

        // Get the allocator from the function_call structure instead of self
        var function_env = std.StringHashMap(f64).init(std.heap.page_allocator);
        defer function_env.deinit();

        // Copy parent environment values (for closure support/global access)
        var it = self.environment.iterator();
        while (it.next()) |entry| {
            try function_env.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Evaluate parameters
        for (function_call.parameters.items, 0..) |param_expr, i| {
            const param_value = try self.evaluate(param_expr);

            // Assuming function has a parameters array/list that holds parameter names
            // Make sure this matches your actual FunctionDeclaration structure
            if (i < function.parameters.items.len) {
                const param_name = function.parameters.items[i];
                try function_env.put(param_name, param_value);
            }
        }

        // Create a temporary evaluator with the function's environment
        var function_evaluator = Evaluator.init(&function_env, self.functions);

        // Execute the function body
        var result: f64 = 0;

        // Execute each statement in the function body
        for (function.block.statements.items) |statement| {
            switch (statement.*) {
                .expression => |expr_stmt| {
                    // Keep track of the last expression result
                    result = try function_evaluator.evaluate(expr_stmt.expression);
                },
                .let => |let_stmt| {
                    const value = try function_evaluator.evaluate(let_stmt.value);
                    try function_env.put(let_stmt.name, value);
                },
                .block => |*block_stmt| {
                    // We need a simplified block execution here
                    // This is a placeholder - you might need to expand this
                    for (block_stmt.statements.items) |block_statement| {
                        if (block_statement.* == .expression) {
                            result = try function_evaluator.evaluate(block_statement.expression.expression);
                        }
                    }
                },
                else => {}, // Ignore other statement types
            }
        }

        return result;
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
