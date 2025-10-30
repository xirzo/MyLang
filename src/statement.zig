const std = @import("std");
const e = @import("expression.zig");
const v = @import("value.zig");
const prog = @import("program.zig");
const errors = @import("errors.zig");

pub const Let = struct {
    name: []const u8,
    value: *e.Expression,

    pub fn deinit(let_stmt: *Let, allocator: std.mem.Allocator) void {
        allocator.free(let_stmt.name);
        let_stmt.value.deinit(allocator);
        allocator.destroy(let_stmt.value);
    }
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

pub const If = struct {
    condition: *e.Expression,
    body: *Block,

    pub fn deinit(self: *If, allocator: std.mem.Allocator) void {
        self.condition.deinit(allocator);
        allocator.destroy(self.condition);
        self.body.deinit(allocator);
        allocator.destroy(self.body);
    }
};

pub const While = struct {
    condition: *e.Expression,
    body: *Block,

    pub fn deinit(self: *While, allocator: std.mem.Allocator) void {
        self.condition.deinit(allocator);
        allocator.destroy(self.condition);
        self.body.deinit(allocator);
        allocator.destroy(self.body);
    }
};

pub const For = struct {
    init: *Let,
    condition: *e.Expression,
    increment: *Statement,
    body: *Block,

    pub fn deinit(self: *For, allocator: std.mem.Allocator) void {
        self.init.deinit(allocator);
        allocator.destroy(self.init);
        self.condition.deinit(allocator);
        allocator.destroy(self.condition);
        self.increment.deinit(allocator);
        allocator.destroy(self.increment);
        self.body.deinit(allocator);
        allocator.destroy(self.body);
    }
};

pub const Assignment = struct {
    name: []const u8,
    value: *e.Expression,
};

pub const Statement = union(enum) {
    let: Let,
    expression: ExpressionStatement,
    block: Block,
    function_declaration: FunctionDeclaration,
    ret: Return,
    if_cond: If,
    while_loop: While,
    for_loop: For,
    assignment: Assignment,

    pub fn deinit(self: *Statement, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .let => |*let_stmt| let_stmt.deinit(allocator),
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
            .ret => |*ret_stmt| {
                if (ret_stmt.value) |value| {
                    value.deinit(allocator);
                    allocator.destroy(value);
                }
            },
            .if_cond => |*if_cond| if_cond.deinit(allocator),
            .while_loop => |*while_loop| while_loop.deinit(allocator),
            .for_loop => |*for_loop| for_loop.deinit(allocator),
            .assignment => |*assign_stmt| {
                allocator.free(assign_stmt.name);
                assign_stmt.value.deinit(allocator);
                allocator.destroy(assign_stmt.value);
            },
        }
    }
};
