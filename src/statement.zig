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

pub const FunctionDeclaration = struct {
    ident: []const u8,
    block: *Block,

    pub fn create(allocator: std.mem.Allocator, name: []const u8, block_stmt: *Block) !*FunctionDeclaration {
        const func = try allocator.create(FunctionDeclaration);
        func.* = FunctionDeclaration{
            .ident = name,
            .block = block_stmt,
        };
        return func;
    }
};

pub const Statement = union(enum) {
    let: Let,
    expression: ExpressionStatement,
    block: Block,
    function_declaration: FunctionDeclaration,

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
                function_declaration.block.deinit(allocator);
                allocator.destroy(function_declaration.block);
            },
        }
    }
};
