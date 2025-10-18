const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");

pub const ExecutionError = ev.EvaluationError || error{
    VariableNotFound,
};

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*Statement),
    environment: std.StringHashMap(f64),
    functions: std.StringHashMap(*FunctionDeclaration),
    evaluator: ev.Evaluator,

    pub fn init(allocator: std.mem.Allocator) Program {
        var program = Program{
            .statements = std.array_list.Managed(*Statement).init(allocator),
            .environment = std.StringHashMap(f64).init(allocator),
            .functions = std.StringHashMap(*FunctionDeclaration).init(allocator),
            .allocator = allocator,
            .evaluator = undefined,
        };
        program.evaluator = ev.Evaluator.init(&program.environment);
        return program;
    }

    pub fn deinit(self: *Program) void {
        std.debug.print("Statements count: {d}\n", .{self.statements.items.len});

        for (self.statements.items) |stmt| {
            stmt.deinit(self.allocator);
            self.allocator.destroy(stmt);
            std.debug.print("Deinited statement\n", .{});
        }

        var func_it = self.functions.iterator();

        while (func_it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }

        self.statements.deinit();
        self.environment.deinit();
        self.functions.deinit();
    }

    pub fn execute(self: *Program) !void {
        for (self.statements.items) |stmt| {
            try stmt.execute(self);
        }
    }

    pub fn registerFunction(self: *Program, func_decl: *FunctionDeclaration) !void {
        try self.functions.put(func_decl.ident, func_decl);
    }

    pub fn getFunction(self: *Program, name: []const u8) ?*FunctionDeclaration {
        return self.functions.get(name);
    }

    pub fn printEnvironment(self: *const Program) void {
        std.debug.print("Environment state:\n", .{});
        var it = self.environment.iterator();
        while (it.next()) |entry| {
            std.debug.print("  {s} = {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        if (self.environment.count() == 0) {
            std.debug.print("  (empty)\n", .{});
        }
    }
};

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

    pub fn execute(self: *Block, program: *Program) ExecutionError!void {
        for (self.statements.items) |block_statement| {
            try block_statement.execute(program);
        }
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

    pub fn execute(self: *Statement, program: *Program) ExecutionError!void {
        switch (self.*) {
            .let => |let_stmt| {
                const value = try program.evaluator.evaluate(let_stmt.value);
                try program.environment.put(let_stmt.name, value);
            },
            .expression => |_| {},
            .block => |*block| try block.execute(program),
            .function_declaration => |*function_declaration| {
                const func = try FunctionDeclaration.create(program.allocator, function_declaration.ident, function_declaration.block);
                try program.registerFunction(func);
            },
        }
    }
};
