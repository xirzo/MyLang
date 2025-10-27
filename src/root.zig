const std = @import("std");

pub const Lexer = @import("lexer.zig").Lexer;
pub const Lexeme = @import("lexer.zig").Lexeme;
pub const Parser = @import("parser.zig").Parser;
pub const ParseError = @import("parser.zig").ParseError;
pub const Evaluator = @import("evaluator.zig").Evaluator;
pub const EvaluationError = @import("evaluator.zig").EvaluationError;
pub const Executor = @import("executor.zig");
pub const ExecutionError = @import("executor.zig").ExecutionError;
pub const Expression = @import("expression.zig").Expression;
pub const Statement = @import("statement.zig").Statement;
pub const Program = @import("program.zig").Program;
pub const Value = @import("value.zig").Value;

pub fn createInterpreter(allocator: std.mem.Allocator, source: []const u8) !*Program {
    const lexer = Lexer.init(source);
    var parser = Parser.init(lexer, allocator);
    return try parser.parse();
}
