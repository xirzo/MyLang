const std = @import("std");
const i = @import("interpreter.zig");
const e = @import("expression.zig");
const s = @import("statement.zig");
const v = @import("value.zig");

pub const Program = struct {
    allocator: std.mem.Allocator,
    statements: std.array_list.Managed(*s.Statement),

    pub fn init(allocator: std.mem.Allocator) !Program {
        return Program{
            .allocator = allocator,
            .statements = std.array_list.Managed(*s.Statement).init(allocator),
        };
    }
    pub fn deinit(self: *Program) void {
        for (self.statements.items) |stmt_item| {
            stmt_item.deinit(self.allocator);
            self.allocator.destroy(stmt_item);
        }

        self.statements.deinit();
    }
};
