const std = @import("std");
const e = @import("expression.zig");
const stmt = @import("statement.zig");
const prog = @import("program.zig");

pub const ExecutionError = prog.ExecutionError;

pub fn executeStatement(statement: *stmt.Statement, program: *prog.Program) ExecutionError!void {
    switch (statement.*) {
        .let => |let_stmt| {
            const value = try program.evaluator.evaluate(let_stmt.value);
            try program.environment.put(let_stmt.name, value);
        },
        .expression => |_| {},
        .block => |*block| try executeBlock(block, program),
        .function_declaration => |*function_declaration| {
            const func = try stmt.FunctionDeclaration.create(program.allocator, function_declaration.ident, function_declaration.block);
            try program.registerFunction(func);
        },
    }
}

pub fn executeBlock(block: *stmt.Block, program: *prog.Program) ExecutionError!void {
    for (block.statements.items) |block_statement| {
        try executeStatement(block_statement, program);
    }
}
