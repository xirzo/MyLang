const std = @import("std");

pub const Lexer = @import("lexer.zig").Lexer;
pub const Lexeme = @import("lexer.zig").Lexeme;
pub const Parser = @import("parser.zig").Parser;
pub const ParseError = @import("parser.zig").ParseError;
pub const EvaluationError = @import("interpreter.zig").EvaluationError;
pub const Interpreter = @import("interpreter.zig").Interpreter;
pub const ExecutionError = @import("interpreter.zig").ExecutionError;
pub const Expression = @import("expression.zig").Expression;
pub const Statement = @import("statement.zig").Statement;
pub const Program = @import("program.zig").Program;
pub const Value = @import("value.zig").Value;

pub fn execute(allocator: std.mem.Allocator, source: []const u8) !void {
    const lexer = Lexer.init(source);
    var parser = Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer program.deinit();

    var interpreter = try Interpreter.init(allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
}
