const std = @import("std");
const e = @import("expression.zig");
const prog = @import("program.zig");

pub const Let = struct {
    name: []const u8,
    value: *e.Expression,
};

pub const ExpressionStatement = struct {
    expression: *e.Expression,
};

pub const Block = struct {
    statements: std.array_list.Managed(*Statement),
    environment: std.StringHashMap(f64),

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
    func: *Block,

    pub fn deinit(self: *Return, allocator: std.mem.Allocator) void {
        self.block.deinit();
        allocator.destroy(self);
    }
};

pub const FunctionDeclaration = struct {
    ident: []const u8,
    block: *Block,
    parameters: std.array_list.Managed([]const u8),
};

pub const Statement = union(enum) {
    let: Let,
    expression: ExpressionStatement,
    block: Block,
    function_declaration: FunctionDeclaration,
    // ret: Return,

    pub fn deinit(self: *Statement, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .let => |let_stmt| {
                let_stmt.value.deinit(allocator);
                allocator.destroy(let_stmt.value);
                allocator.free(let_stmt.name);
            },
            .expression => |expr_stmt| {
                expr_stmt.expression.deinit(allocator);
                allocator.destroy(expr_stmt.expression);
            },
            .block => |*block| block.deinit(allocator),
            .function_declaration => |function_declaration| {
                // for (function_declaration.parameters) |parameter| {
                //     allocator.free(parameter);
                // }
                function_declaration.block.deinit(allocator);
                allocator.destroy(function_declaration.block);
            },
            // .ret => |ret| ret.deinit(allocator),
        }
    }
};
