const std = @import("std");
const e = @import("expression.zig");
const v = @import("value.zig");
const s = @import("statement.zig");
const p = @import("program.zig");
const errors = @import("errors.zig");

pub const BuiltinFunction = struct {
    name: []const u8,
    executor: *const fn (program: *Interpreter, args: []const v.Value) errors.ExecutionError!v.Value,
};

pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    environment: std.StringHashMap(v.Value),
    functions: std.StringHashMap(*s.FunctionDeclaration),
    builtin_functions: std.StringHashMap(*BuiltinFunction),
    ret_value: *v.Value,
    should_return: bool,

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        const ret_value = try allocator.create(v.Value);
        ret_value.* = v.Value{ .none = {} };

        var interpreter = Interpreter{
            .allocator = allocator,
            .environment = std.StringHashMap(v.Value).init(allocator),
            .functions = std.StringHashMap(*s.FunctionDeclaration).init(allocator),
            .builtin_functions = std.StringHashMap(*BuiltinFunction).init(allocator),
            .ret_value = ret_value,
            .should_return = false,
        };

        try interpreter.registerBuiltins();

        return interpreter;
    }

    pub fn deinit(self: *Interpreter) void {
        var env_iter = self.environment.iterator();

        while (env_iter.next()) |entry| {
            var value = entry.value_ptr;
            value.deinit(self.allocator);
        }

        var builtins_iter = self.builtin_functions.iterator();

        while (builtins_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.name);
            self.allocator.destroy(entry.value_ptr.*);
        }

        self.allocator.destroy(self.ret_value);

        self.environment.deinit();
        self.functions.deinit();
        self.builtin_functions.deinit();
    }

    fn registerBuiltins(self: *Interpreter) !void {
        const println_fn = try self.allocator.create(BuiltinFunction);

        println_fn.* = .{
            .name = try self.allocator.dupe(u8, "println"),
            .executor = printlnExecutor,
        };

        try self.builtin_functions.put(println_fn.name, println_fn);

        const strlen_fn = try self.allocator.create(BuiltinFunction);

        strlen_fn.* = .{
            .name = try self.allocator.dupe(u8, "strlen"),
            .executor = strlen,
        };

        try self.builtin_functions.put(strlen_fn.name, strlen_fn);
    }

    pub fn evaluate(self: *Interpreter, expr: *e.Expression) errors.EvaluationError!v.Value {
        return switch (expr.*) {
            .constant => |constant| self.evaluateConstant(constant),
            .variable => |vrbl| self.evaluateVariable(vrbl),
            .binary_operator => |o| self.evaluateBinaryOperator(o),
            .function_call => |*function_call| self.evaluateFunctionCall(function_call),
            .comparison_operator => |*comp| self.evaluateComparison(comp.*),
            .object_access => |obj_access| self.evaluateObjectAccess(obj_access),
        };
    }

    fn evaluateConstant(self: *Interpreter, constant: e.Constant) errors.EvaluationError!v.Value {
        return switch (constant) {
            .number => |num| v.Value{ .number = num },
            .string => |str| blk: {
                const dupe = try self.allocator.dupe(u8, str);
                const value = v.Value{ .string = dupe };
                break :blk value;
            },
            .char => |ch| v.Value{ .char = ch },
            .boolean => |b| v.Value{ .boolean = b },
            .array => |arr| self.evaluateArray(arr),
            .object => |obj_fields| self.evaluateObject(obj_fields),
        };
    }

    fn evaluateArray(self: *Interpreter, arr: std.array_list.Managed(*e.Expression)) errors.EvaluationError!v.Value {
        var elements = std.array_list.Managed(v.Value).init(self.allocator);

        for (arr.items) |el| {
            try elements.append(try self.evaluate(el));
        }

        return v.Value{ .array = elements };
    }

    fn evaluateVariable(self: *Interpreter, vrbl: e.Variable) errors.EvaluationError!v.Value {
        return self.environment.get(vrbl.name) orelse error.UndefinedVariable;
    }

    fn evaluateBinaryOperator(self: *Interpreter, op: e.BinaryOperator) errors.EvaluationError!v.Value {
        const lhs = if (op.lhs) |l| try self.evaluate(l) else {
            return error.NoLeftExpression;
        };

        const rhs = if (op.rhs) |r| try self.evaluate(r) else {
            return error.NoRightExpression;
        };

        return switch (op.value) {
            '+' => try addValues(self.allocator, lhs, rhs),
            '-' => try subtractValues(lhs, rhs),
            '*' => try multiplyValues(self.allocator, lhs, rhs),
            '/' => try divideValues(lhs, rhs),
            '!' => try factorialValue(lhs),
            '[' => try indexArray(lhs, rhs),
            else => error.UnsupportedOperator,
        };
    }

    fn evaluateFunctionCall(self: *Interpreter, function_call: *e.FunctionCall) errors.EvaluationError!v.Value {
        if (self.builtin_functions.get(function_call.function_name)) |builtin_ptr| {
            const builtin = builtin_ptr.*;
            var args = std.array_list.Managed(v.Value).init(self.allocator);
            defer args.deinit();

            for (function_call.parameters.items) |param_expr| {
                const param_value = try self.evaluate(param_expr);
                try args.append(param_value);
            }

            self.should_return = false;
            return builtin.executor(self, args.items);
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

        const saved_ret_value = self.ret_value.*;
        self.ret_value.* = v.Value{ .none = {} };
        self.should_return = false;

        try self.executeBlock(func.block);

        const return_value = self.ret_value.*;

        self.environment.clearRetainingCapacity();
        var saved_iter = saved_vars.iterator();
        while (saved_iter.next()) |entry| {
            try self.environment.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        self.ret_value.* = saved_ret_value;

        return return_value;
    }

    fn evaluateComparison(self: *Interpreter, comp: e.ComparisonOperator) errors.EvaluationError!v.Value {
        const lhs = try self.evaluate(comp.lhs);
        const rhs = try self.evaluate(comp.rhs);

        return compareValues(lhs, rhs, comp.op);
    }

    fn evaluateObject(self: *Interpreter, obj_fields: std.array_list.Managed(e.ObjectField)) errors.EvaluationError!v.Value {
        var object = std.StringHashMap(v.Value).init(self.allocator);

        for (obj_fields.items) |field| {
            const value = try self.evaluate(field.value);
            try object.put(field.key, value);
        }

        return v.Value{ .object = object };
    }

    fn evaluateObjectAccess(self: *Interpreter, obj_access: e.ObjectAccess) errors.EvaluationError!v.Value {
        const object_value = try self.evaluate(obj_access.object);

        const object = switch (object_value) {
            .object => |obj| obj,
            else => return error.TypeMismatch,
        };

        return object.get(obj_access.key) orelse error.UndefinedProperty;
    }

    pub fn execute(self: *Interpreter, program: *p.Program) errors.ExecutionError!void {
        for (program.statements.items) |statement| {
            try self.executeStatement(statement);
        }
    }

    fn executeStatement(self: *Interpreter, statement: *s.Statement) errors.ExecutionError!void {
        switch (statement.*) {
            .let => |let_stmt| {
                const value = try self.evaluate(let_stmt.value);
                try self.environment.put(let_stmt.name, value);
            },
            .expression => |expr_stmt| {
                _ = try self.evaluate(expr_stmt.expression);
            },
            .block => |*block| try executeBlock(self, block),
            .function_declaration => |*function_declaration| {
                try self.functions.put(function_declaration.name, function_declaration);
            },
            .ret => |*ret| try executeReturn(self, ret),
            .if_cond => |*if_cond| try executeIf(self, if_cond),
            .while_loop => |*while_loop| try executeWhile(self, while_loop),
            .assignment => |*assign_stmt| {
                if (!self.environment.contains(assign_stmt.name)) {
                    std.log.err("undefined variable: {s}", .{assign_stmt.name});
                    return error.UndefinedVariable;
                }

                const value = try self.evaluate(assign_stmt.value);

                try self.environment.put(assign_stmt.name, value);
            },
            .for_loop => |*for_loop| try executeForLoop(self, for_loop),
        }
    }

    fn executeBlock(self: *Interpreter, block: *s.Block) errors.ExecutionError!void {
        for (block.statements.items) |block_statement| {
            try self.executeStatement(block_statement);

            if (self.should_return) {
                return;
            }
        }
    }

    fn executeReturn(self: *Interpreter, ret: *s.Return) errors.ExecutionError!void {
        if (ret.value) |val| {
            self.ret_value.* = try self.evaluate(val);
            self.should_return = true;
        }
    }

    fn executeIf(self: *Interpreter, if_stmt: *s.If) errors.ExecutionError!void {
        const value = try self.evaluate(if_stmt.condition);

        const should_execute = switch (value) {
            .number => |n| n > 0,
            .string => |str| str.len > 0,
            .char => |c| c > 0,
            .boolean => |b| b == true,
            .none => false,
            .array => |arr| arr.items.len > 0,
            .object => true,
        };

        if (!should_execute) {
            return;
        }

        try self.executeBlock(if_stmt.body);
    }

    fn executeWhile(self: *Interpreter, while_loop: *s.While) errors.ExecutionError!void {
        while (true) {
            const value = try self.evaluate(while_loop.condition);

            const should_execute = switch (value) {
                .number => |n| n > 0,
                .string => |str| str.len > 0,
                .char => |c| c > 0,
                .boolean => |b| b == true,
                .none => false,
                .array => |arr| arr.items.len > 0,
                .object => true,
            };

            if (!should_execute) {
                break;
            }

            try self.executeBlock(while_loop.body);

            if (self.should_return) {
                return;
            }
        }
    }

    fn executeForLoop(self: *Interpreter, for_loop: *s.For) errors.ExecutionError!void {
        const original_env_count = self.environment.count();

        try self.executeStatement(for_loop.init);

        while (true) {
            const condition_value = try self.evaluate(for_loop.condition);

            const should_continue = switch (condition_value) {
                .number => |n| n > 0,
                .string => |str| str.len > 0,
                .char => |c| c > 0,
                .boolean => |b| b == true,
                .none => false,
                .array => |arr| arr.items.len > 0,
                .object => true,
            };

            if (!should_continue) {
                break;
            }

            try self.executeBlock(for_loop.body);

            if (self.should_return) {
                return;
            }

            try self.executeStatement(for_loop.increment);
        }

        var env_iter = self.environment.iterator();
        var keys_to_remove = std.array_list.Managed([]const u8).init(self.allocator);
        defer keys_to_remove.deinit();

        var current_count: usize = 0;
        while (env_iter.next()) |_| {
            current_count += 1;
            if (current_count > original_env_count) {
                break;
            }
        }
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

fn addValues(allocator: std.mem.Allocator, lhs: v.Value, rhs: v.Value) errors.EvaluationError!v.Value {
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
                .object => return error.TypeMismatch,
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
                .object => return error.TypeMismatch,
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
                .object => return error.TypeMismatch,
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
                .object => return error.TypeMismatch,
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
                    var result = std.array_list.Managed(v.Value).init(allocator);

                    try result.ensureTotalCapacity(larr.items.len + rarr.items.len);

                    for (larr.items) |item| {
                        const cloned = try cloneValue(allocator, item);
                        result.appendAssumeCapacity(cloned);
                    }

                    for (rarr.items) |item| {
                        const cloned = try cloneValue(allocator, item);
                        result.appendAssumeCapacity(cloned);
                    }

                    return v.Value{ .array = result };
                },
                .object => return error.TypeMismatch,
                .none => return lhs,
            }
        },
        .object => return error.TypeMismatch,
        .none => return rhs,
    }
}

fn cloneValue(allocator: std.mem.Allocator, value: v.Value) !v.Value {
    switch (value) {
        .number => |n| return v.Value{ .number = n },
        .string => |str| {
            const cloned_str = try allocator.alloc(u8, str.len);
            @memcpy(cloned_str, str);
            return v.Value{ .string = cloned_str };
        },
        .char => |c| return v.Value{ .char = c },
        .boolean => |b| return v.Value{ .boolean = b },
        .array => |arr| {
            var cloned_arr = std.array_list.Managed(v.Value).init(allocator);
            try cloned_arr.ensureTotalCapacity(arr.items.len);
            for (arr.items) |item| {
                const cloned_item = try cloneValue(allocator, item);
                cloned_arr.appendAssumeCapacity(cloned_item);
            }
            return v.Value{ .array = cloned_arr };
        },
        .object => |obj| {
            var cloned_object = std.StringHashMap(v.Value).init(allocator);
            var iterator = obj.iterator();
            while (iterator.next()) |entry| {
                const cloned_value = try cloneValue(allocator, entry.value_ptr.*);
                try cloned_object.put(entry.key_ptr.*, cloned_value);
            }
            return v.Value{ .object = cloned_object };
        },
        .none => return v.Value{ .none = {} },
    }
}

fn subtractValues(lhs: v.Value, rhs: v.Value) errors.EvaluationError!v.Value {
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

fn multiplyValues(allocator: std.mem.Allocator, lhs: v.Value, rhs: v.Value) errors.EvaluationError!v.Value {
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

fn divideValues(lhs: v.Value, rhs: v.Value) errors.EvaluationError!v.Value {
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

fn factorialValue(val: v.Value) errors.EvaluationError!v.Value {
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

fn compareValues(lhs: v.Value, rhs: v.Value, op: []const u8) errors.EvaluationError!v.Value {
    const result = switch (lhs) {
        .number => |lnum| blk: {
            const rnum = switch (rhs) {
                .number => |n| n,
                else => return error.TypeMismatch,
                // just a variable
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

fn indexArray(array_val: v.Value, index_val: v.Value) errors.EvaluationError!v.Value {
    const index = switch (index_val) {
        .number => |num| blk: {
            if (num < 0 or num != @trunc(num)) {
                return error.InvalidIndex;
            }

            break :blk @as(usize, @intFromFloat(num));
        },
        else => return error.TypeMismatch,
    };

    return switch (array_val) {
        .array => |arr| blk: {
            if (index >= arr.items.len) {
                return error.IndexOutOfBounds;
            }

            break :blk arr.items[index];
        },
        .string => |str| blk: {
            if (index >= str.len) {
                return error.IndexOutOfBounds;
            }

            break :blk v.Value{ .char = str[index] };
        },
        else => return error.TypeMismatch,
    };
}

fn printValue(writer: *std.fs.File.Writer, value: v.Value) !void {
    switch (value) {
        .number => |n| try writer.interface.print("{d}", .{n}),
        .string => |str| try writer.interface.print("{s}", .{str}),
        .char => |c| try writer.interface.print("{c}", .{c}),
        .boolean => |b| try writer.interface.print("{}", .{b}),
        .array => |arr| {
            try writer.interface.print("[", .{});
            for (arr.items, 0..) |item, i| {
                if (i > 0) {
                    try writer.interface.print(", ", .{});
                }

                try printValue(writer, item);
            }
            try writer.interface.print("]", .{});
        },
        .object => |obj| {
            try writer.interface.print("{{", .{});

            var iterator = obj.iterator();
            var first = true;

            while (iterator.next()) |entry| {
                if (!first) {
                    try writer.interface.print(", ", .{});
                }
                first = false;

                try writer.interface.print("{s}: ", .{entry.key_ptr.*});

                try printValue(writer, entry.value_ptr.*);
            }

            try writer.interface.print("}}", .{});
        },
        .none => try writer.interface.print("(none)", .{}),
    }
}

fn printlnExecutor(self: *Interpreter, args: []const v.Value) errors.ExecutionError!v.Value {
    _ = self;

    var buf: [1024]u8 = undefined;
    var writer = std.fs.File.writer(std.fs.File.stdout(), &buf);

    if (args.len == 0) {
        try writer.interface.print("\n", .{});
    } else {
        try printValue(&writer, args[0]);
        try writer.interface.print("\n", .{});
    }

    try writer.interface.flush();

    return v.Value{ .none = {} };
}

fn strlen(self: *Interpreter, args: []const v.Value) errors.ExecutionError!v.Value {
    _ = self;

    if (args.len != 1) {
        return error.WrongArgumentCount;
    }

    if (args[0] != .string) {
        return error.TypeMismatch;
    }

    return v.Value{ .number = @as(f64, @floatFromInt(args[0].string.len)) };
}
