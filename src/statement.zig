const std = @import("std");
const e = @import("expression.zig");
const v = @import("value.zig");
const prog = @import("program.zig");
const ex = @import("executor.zig");

pub const Let = struct {
    name: []const u8,
    value: *e.Expression,
};

pub const ExpressionStatement = struct {
    expression: *e.Expression,
};

pub const Block = struct {
    statements: std.array_list.Managed(*Statement),
    environment: std.StringHashMap(v.Value),

    pub fn deinit(self: *Block, allocator: std.mem.Allocator) void {
        for (self.statements.items) |block_statement| {
            block_statement.deinit(allocator);
            allocator.destroy(block_statement);
        }

        self.statements.deinit();
        self.environment.deinit();
    }
};

pub const Return = struct {
    value: ?*e.Expression,

    pub fn deinit(self: *Return, allocator: std.mem.Allocator) void {
        if (self.value) |val| {
            val.deinit(allocator);
            allocator.destroy(val);
        }
    }
};

pub const BuiltinFunction = struct {
    name: []const u8,
    executor: *const fn (program: *prog.Program, args: []const v.Value) ex.ExecutionError!v.Value,
};

pub const FunctionDeclaration = struct {
    name: []const u8,
    block: *Block,
    parameters: std.array_list.Managed([]const u8),

    pub fn deinit(self: *FunctionDeclaration, allocator: std.mem.Allocator) void {
        for (self.parameters.items) |param_name| {
            allocator.free(param_name);
        }

        self.parameters.deinit();
        self.block.deinit(allocator);
        allocator.destroy(self.block);
    }
};

pub const Statement = union(enum) {
    let: Let,
    expression: ExpressionStatement,
    block: Block,
    function_declaration: FunctionDeclaration,
    builtin_function: BuiltinFunction,
    ret: Return,

    pub fn deinit(self: *Statement, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .let => |*let_stmt| {
                allocator.free(let_stmt.name);
                let_stmt.value.deinit(allocator);
                allocator.destroy(let_stmt.value);
            },
            .expression => |*expr_stmt| {
                expr_stmt.expression.deinit(allocator);
                allocator.destroy(expr_stmt.expression);
            },
            .block => |*block| {
                block.deinit(allocator);
            },
            .function_declaration => |*function_declaration| {
                function_declaration.deinit(allocator);
            },
            .builtin_function => |*builtin| {
                allocator.free(builtin.name);
            },
            .ret => |*ret_stmt| {
                if (ret_stmt.value) |value| {
                    value.deinit(allocator);
                    allocator.destroy(value);
                }
            },
        }
    }
};
