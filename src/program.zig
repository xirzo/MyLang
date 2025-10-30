const std = @import("std");
const e = @import("expression.zig");
const ev = @import("evaluator.zig");
const v = @import("value.zig");
const stmt = @import("statement.zig");
const exec = @import("executor.zig");

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*stmt.Statement),
    environment: std.StringHashMap(v.Value),
    functions: std.StringHashMap(*stmt.FunctionDeclaration),
    builtins: std.StringHashMap(*stmt.BuiltinFunction),
    evaluator: ev.Evaluator,
    ret_value: *v.Value,
    should_return: bool,

    pub fn init(allocator: std.mem.Allocator) !Program {
        const ret_value = try allocator.create(v.Value);
        ret_value.* = v.Value{ .none = {} };

        var program = Program{
            .statements = std.array_list.Managed(*stmt.Statement).init(allocator),
            .environment = std.StringHashMap(v.Value).init(allocator),
            .functions = std.StringHashMap(*stmt.FunctionDeclaration).init(allocator),
            .builtins = std.StringHashMap(*stmt.BuiltinFunction).init(allocator),
            .allocator = allocator,
            .evaluator = undefined,
            .ret_value = ret_value,
            .should_return = false,
        };

        try program.registerBuiltins();

        return program;
    }

    pub fn initEvaluator(self: *Program) void {
        self.evaluator = ev.Evaluator.init(self, &self.environment, &self.functions);
    }

    pub fn deinit(self: *Program) void {
        for (self.statements.items) |stmt_item| {
            stmt_item.deinit(self.allocator);
            self.allocator.destroy(stmt_item);
        }

        var env_iter = self.environment.iterator();

        while (env_iter.next()) |entry| {
            var value = entry.value_ptr;
            value.deinit(self.allocator);
        }

        var builtins_iter = self.builtins.iterator();

        while (builtins_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.name);
            self.allocator.destroy(entry.value_ptr.*);
        }

        self.statements.deinit();
        self.environment.deinit();
        self.functions.deinit();
        self.builtins.deinit();

        self.ret_value.deinit(self.allocator);
        self.allocator.destroy(self.ret_value);
    }

    pub fn registerBuiltins(self: *Program) !void {
        const println_fn = try self.allocator.create(stmt.BuiltinFunction);

        println_fn.* = .{
            .name = try self.allocator.dupe(u8, "println"),
            .executor = exec.printlnExecutor,
        };

        try self.builtins.put("println", println_fn);
    }

    pub fn execute(self: *Program) !void {
        for (self.statements.items) |stmt_item| {
            try exec.executeStatement(stmt_item, self);
        }
    }

    pub fn registerFunction(self: *Program, func_decl: *stmt.FunctionDeclaration) !void {
        std.log.debug("Registering function: {s}\n", .{func_decl.name});
        try self.functions.put(func_decl.name, func_decl);
        std.log.debug("Functions count after registration: {d}\n", .{self.functions.count()});
    }

    pub fn getFunction(self: *Program, name: []const u8) ?*stmt.FunctionDeclaration {
        return self.functions.get(name);
    }
};
