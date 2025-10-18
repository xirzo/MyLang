const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");
const stmt = @import("statement.zig");
const exec = @import("executor.zig");

pub const ExecutionError = ev.EvaluationError || error{
    VariableNotFound,
};

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*stmt.Statement),
    environment: std.StringHashMap(f64),
    functions: std.StringHashMap(*stmt.FunctionDeclaration),
    evaluator: ev.Evaluator,

    pub fn init(allocator: std.mem.Allocator) Program {
        var program = Program{
            .statements = std.array_list.Managed(*stmt.Statement).init(allocator),
            .environment = std.StringHashMap(f64).init(allocator),
            .functions = std.StringHashMap(*stmt.FunctionDeclaration).init(allocator),
            .allocator = allocator,
            .evaluator = undefined,
        };
        program.evaluator = ev.Evaluator.init(&program.environment);
        return program;
    }

    pub fn deinit(self: *Program) void {
        std.debug.print("Statements count: {d}\n", .{self.statements.items.len});

        for (self.statements.items) |stmt_item| {
            stmt_item.deinit(self.allocator);
            self.allocator.destroy(stmt_item);
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
        for (self.statements.items) |stmt_item| {
            try exec.executeStatement(stmt_item, self);
        }
    }

    pub fn registerFunction(self: *Program, func_decl: *stmt.FunctionDeclaration) !void {
        try self.functions.put(func_decl.ident, func_decl);
    }

    pub fn getFunction(self: *Program, name: []const u8) ?*stmt.FunctionDeclaration {
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
