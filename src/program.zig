const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");
const v = @import("value.zig");
const stmt = @import("statement.zig");
const exec = @import("executor.zig");
const errors = @import("errors.zig");

pub const ExecutionError = errors.ExecutionError;

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*stmt.Statement),
    environment: std.StringHashMap(v.Value),
    functions: std.StringHashMap(*stmt.FunctionDeclaration),
    evaluator: ev.Evaluator,
    // TODO: replace with value union
    ret_value: *v.Value,

    pub fn init(allocator: std.mem.Allocator) !Program {
        const ret_value = try allocator.create(v.Value);
        ret_value.* = v.Value{ .none = {} };

        return Program{
            .statements = std.array_list.Managed(*stmt.Statement).init(allocator),
            .environment = std.StringHashMap(v.Value).init(allocator),
            .functions = std.StringHashMap(*stmt.FunctionDeclaration).init(allocator),
            .allocator = allocator,
            .evaluator = undefined,
            .ret_value = ret_value,
        };
    }

    pub fn initEvaluator(self: *Program) void {
        self.evaluator = ev.Evaluator.init(self, &self.environment, &self.functions);
    }

    pub fn deinit(self: *Program) void {
        std.debug.print("Statements count: {d}\n", .{self.statements.items.len});

        for (self.statements.items) |stmt_item| {
            stmt_item.deinit(self.allocator);
            self.allocator.destroy(stmt_item);
            std.debug.print("Deinited statement\n", .{});
        }

        self.statements.deinit();
        self.environment.deinit();
        self.functions.deinit();
        self.allocator.destroy(self.ret_value);
    }

    pub fn execute(self: *Program) !void {
        for (self.statements.items) |stmt_item| {
            try exec.executeStatement(stmt_item, self);
        }
    }

    pub fn registerFunction(self: *Program, func_decl: *stmt.FunctionDeclaration) !void {
        std.debug.print("Registering function: {s}\n", .{func_decl.ident});
        try self.functions.put(func_decl.ident, func_decl);
        std.debug.print("Functions count after registration: {d}\n", .{self.functions.count()});
    }

    pub fn getFunction(self: *Program, name: []const u8) ?*stmt.FunctionDeclaration {
        return self.functions.get(name);
    }

    pub fn printEnvironment(_: *const Program) void {
        // std.debug.print("Environment state:\n", .{});
        //
        // var it = self.environment.iterator();
        //
        // while (it.next()) |entry| {
        //     switch (entry.value_ptr.*) {
        //         .number => std.debug.print("  {s} = {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* }),
        //         else => unreachable,
        //     }
        // }
        //
        // if (self.environment.count() == 0) {
        //     std.debug.print("  (empty)\n", .{});
        // }
    }
};
