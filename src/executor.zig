const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");
const stmt = @import("statement.zig");
const prog = @import("program.zig");
const v = @import("value.zig");
const errors = @import("errors.zig");

pub const ExecutionError = errors.ExecutionError;

pub fn executeStatement(statement: *stmt.Statement, program: *prog.Program) ExecutionError!void {
    switch (statement.*) {
        .let => |let_stmt| {
            const value = try program.evaluator.evaluate(let_stmt.value);
            try program.environment.put(let_stmt.name, value);
        },
        .expression => |expr_stmt| {
            _ = try program.evaluator.evaluate(expr_stmt.expression);
        },
        .block => |*block| try executeBlock(block, program),
        .function_declaration => |*function_declaration| {
            try program.registerFunction(function_declaration);
        },
        .builtin_function => |_| {
            // NOTE: this code actually is not needed, as it will never be executed
            //     const builtin_fn = try program.allocator.create(stmt.BuiltinFunction);
        },
        .ret => |*ret| try executeReturn(ret, program),
        .if_cond => |*if_cond| try executeIf(if_cond, program),
        .while_loop => |*while_loop| try executeWhile(while_loop, program),
        .assignment => |*assign_stmt| {
            if (!program.environment.contains(assign_stmt.name)) {
                std.log.err("undefined variable: {s}", .{assign_stmt.name});
                return error.UndefinedVariable;
            }

            const value = try program.evaluator.evaluate(assign_stmt.value);

            try program.environment.put(assign_stmt.name, value);
        },
    }
}

pub fn executeBlock(block: *stmt.Block, program: *prog.Program) ExecutionError!void {
    for (block.statements.items) |block_statement| {
        try executeStatement(block_statement, program);

        if (program.should_return) {
            return;
        }
    }
}

fn executeReturn(ret: *stmt.Return, program: *prog.Program) ExecutionError!void {
    if (ret.value) |val| {
        program.ret_value.* = try program.evaluator.evaluate(val);
        program.should_return = true;
    }
}

fn executeIf(if_stmt: *stmt.If, program: *prog.Program) ExecutionError!void {
    const value = try program.evaluator.evaluate(if_stmt.condition);

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

    try executeBlock(if_stmt.body, program);
}

fn executeWhile(while_loop: *stmt.While, program: *prog.Program) ExecutionError!void {
    const value = try program.evaluator.evaluate(while_loop.condition);

    const should_execute = switch (value) {
        .number => |n| n > 0,
        .string => |str| str.len > 0,
        .char => |c| c > 0,
        .boolean => |b| b == true,
        .none => false,
        .array => |arr| arr.items.len > 0,
        .object => true,
    };

    while (should_execute) {
        try executeBlock(while_loop.body, program);
    }
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

pub fn printlnExecutor(program: *prog.Program, args: []const v.Value) ExecutionError!v.Value {
    _ = program;
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
