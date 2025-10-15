const std = @import("std");
const Lexeme = @import("lexer.zig").Lexeme;
const Expression = @import("expression.zig").Expression;

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*Statement),
    environment: std.StringHashMap(f64),

    pub fn init(allocator: std.mem.Allocator) Program {
        return Program{
            .statements = std.array_list.Managed(*Statement).init(allocator),
            .environment = std.StringHashMap(f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Program) void {
        std.debug.print("Statements count: {d}\n", .{self.statements.items.len});

        for (self.statements.items) |stmt| {
            stmt.deinit(self.allocator);
            self.allocator.destroy(stmt);
            std.debug.print("Deinited statement\n", .{});
        }

        self.statements.deinit();
        self.environment.deinit();
    }

    pub fn execute(self: *Program) !void {
        for (self.statements.items) |stmt| {
            try stmt.execute(&self.environment);
        }
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
    value: *Expression,
};

pub const ExpressionStatement = struct {
    expression: *Expression,
};

pub const Statement = union(enum) {
    let: Let,
    expression: ExpressionStatement,

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
        }
    }

    pub fn execute(self: *const Statement, environment: *std.StringHashMap(f64)) !void {
        switch (self.*) {
            .let => |let_stmt| {
                const value = try let_stmt.value.eval(environment);
                try environment.put(let_stmt.name, value);
            },
            .expression => |_| {},
        }
    }
};
