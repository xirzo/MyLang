const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");
const stmt = @import("statement.zig");
const prog = @import("program.zig");
const errors = @import("errors.zig");

pub const ExecutionError = errors.ExecutionError;

pub fn executeStatement(statement: *stmt.Statement, program: *prog.Program) ExecutionError!void {
    switch (statement.*) {
        .let => |let_stmt| {
            const value = try program.evaluator.evaluate(let_stmt.value);
            try program.environment.put(let_stmt.name, value);
        },
        .expression => |_| {},
        .block => |*block| try executeBlock(block, program),
        .function_declaration => |*function_declaration| {
            try program.registerFunction(function_declaration);
        },
        .ret => |*ret| try executeReturn(ret, program),
    }
}

fn executeBlock(block: *stmt.Block, program: *prog.Program) ExecutionError!void {
    for (block.statements.items) |block_statement| {
        try executeStatement(block_statement, program);
    }
}

fn executeReturn(ret: *stmt.Return, program: *prog.Program) ExecutionError!void {
    if (ret.value == null) {
        program.ret_value = null;
        return;
    }

    if (program.ret_value == null) {
        program.ret_value = try program.allocator.create(f64);
    }

    program.ret_value.?.* = try program.evaluator.evaluate(ret.value.?);
}
