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
    };

    if (!should_execute) {
        return;
    }

    try executeBlock(if_stmt.body, program);
}

pub fn printlnExecutor(program: *prog.Program, args: []const v.Value) ExecutionError!v.Value {
    _ = program;

    var buf: [1024]u8 = undefined;
    var writer = std.fs.File.writer(std.fs.File.stdout(), &buf);

    if (args.len == 0) {
        std.log.debug("\n", .{});
    } else {
        switch (args[0]) {
            .number => |n| try writer.interface.print("{}\n", .{n}),
            .string => |str| try writer.interface.print("{s}\n", .{str}),
            .char => |c| try writer.interface.print("{c}\n", .{c}),
            .boolean => |b| try writer.interface.print("{}\n", .{b}),
            // TODO: add proper printing
            .array => |arr| try writer.interface.print("{}\n", .{arr}),
            .none => try writer.interface.print("(none)\n", .{}),
        }
    }

    try writer.interface.flush();

    return v.Value{ .none = {} };
}
