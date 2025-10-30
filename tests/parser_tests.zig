const std = @import("std");
const testing = std.testing;
const mylang = @import("mylang");

fn parseAndGetFirstExpression(allocator: std.mem.Allocator, source: []const u8) !*mylang.Expression {
    const lexer = mylang.Lexer.init(source);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    if (program.statements.items.len > 0) {
        switch (program.statements.items[0].*) {
            .expression => |expr_stmt| {
                const expr = try allocator.create(mylang.Expression);

                expr.* = expr_stmt.expression.*;
                return expr;
            },
            else => return error.NotAnExpression,
        }
    }
    return error.NoStatements;
}

fn parseAndGetFirstStatement(allocator: std.mem.Allocator, source: []const u8) !*mylang.Statement {
    const lexer = mylang.Lexer.init(source);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    if (program.statements.items.len > 0) {
        const stmt = try allocator.create(mylang.Statement);
        stmt.* = program.statements.items[0].*;
        return stmt;
    }
    return error.NoStatements;
}

test "parse number literal" {
    const allocator = testing.allocator;
    const src = "42;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    try testing.expectEqual(@as(usize, 1), program.statements.items.len);
    try testing.expect(program.statements.items[0].* == .expression);

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .constant);
    try testing.expect(expr.constant == .number);
    try testing.expectEqual(@as(f64, 42), expr.constant.number);
}

test "parse number literal with dot" {
    const allocator = testing.allocator;
    const src = "3.14;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.constant == .number);
    try testing.expectEqual(@as(f64, 3.14), expr.constant.number);
}

test "parse string literal" {
    const allocator = testing.allocator;
    const src = "\"hello world\";";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.constant == .string);
    try testing.expectEqualStrings("hello world", expr.constant.string);
}

test "parse true literal" {
    const allocator = testing.allocator;
    const src = "true;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.constant == .boolean);
    try testing.expect(expr.constant.boolean == true);
}

test "parse false literal" {
    const allocator = testing.allocator;
    const src = "false;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.constant == .boolean);
    try testing.expect(expr.constant.boolean == false);
}

test "parse variable reference" {
    const allocator = testing.allocator;
    const src = "myVariable;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .variable);
    try testing.expectEqualStrings("myVariable", expr.variable.name);
}

test "parse function call without parameters" {
    const allocator = testing.allocator;
    const src = "println();";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .function_call);
    try testing.expectEqualStrings("println", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 0), expr.function_call.parameters.items.len);
}

test "parse function call with parameters" {
    const allocator = testing.allocator;
    const src = "add(1, 2, x);";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .function_call);
    try testing.expectEqualStrings("add", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 3), expr.function_call.parameters.items.len);

    try testing.expect(expr.function_call.parameters.items[0].* == .constant);
    try testing.expectEqual(@as(f64, 1), expr.function_call.parameters.items[0].constant.number);

    try testing.expect(expr.function_call.parameters.items[1].* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.function_call.parameters.items[1].constant.number);

    try testing.expect(expr.function_call.parameters.items[2].* == .variable);
    try testing.expectEqualStrings("x", expr.function_call.parameters.items[2].variable.name);
}

test "parse binary operators" {
    const allocator = testing.allocator;

    const test_cases = [_]struct { source: []const u8, op: u8 }{
        .{ .source = "1 + 2;", .op = '+' },
        .{ .source = "5 - 3;", .op = '-' },
        .{ .source = "4 * 6;", .op = '*' },
        .{ .source = "8 / 2;", .op = '/' },
    };

    for (test_cases) |case| {
        const lexer = mylang.Lexer.init(case.source);
        var parser = mylang.Parser.init(allocator, lexer);
        const program = try parser.parse();
        defer {
            program.deinit();
            allocator.destroy(program);
        }

        const expr = program.statements.items[0].expression.expression;
        try testing.expect(expr.* == .binary_operator);
        try testing.expectEqual(case.op, expr.binary_operator.value);
        try testing.expect(expr.binary_operator.lhs != null);
        try testing.expect(expr.binary_operator.rhs != null);
    }
}

test "parse unary prefix operators" {
    const allocator = testing.allocator;

    const test_cases = [_]struct { source: []const u8, op: u8 }{
        .{ .source = "+5;", .op = '+' },
        .{ .source = "-10;", .op = '-' },
    };

    for (test_cases) |case| {
        const lexer = mylang.Lexer.init(case.source);
        var parser = mylang.Parser.init(allocator, lexer);
        const program = try parser.parse();
        defer {
            program.deinit();
            allocator.destroy(program);
        }

        const expr = program.statements.items[0].expression.expression;
        try testing.expect(expr.* == .binary_operator);
        try testing.expectEqual(case.op, expr.binary_operator.value);
        try testing.expect(expr.binary_operator.lhs == null);
        try testing.expect(expr.binary_operator.rhs != null);
    }
}

test "parse postfix operators" {
    const allocator = testing.allocator;
    const src = "x!;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .binary_operator);
    try testing.expectEqual(@as(u8, '!'), expr.binary_operator.value);
    try testing.expect(expr.binary_operator.lhs != null);
    try testing.expect(expr.binary_operator.rhs == null);
}

test "parse parenthesized expressions" {
    const allocator = testing.allocator;
    const src = "(42);";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .constant);
    try testing.expectEqual(@as(f64, 42), expr.constant.number);
}

test "operator precedence" {
    const allocator = testing.allocator;
    const src = "2 + 3 * 4;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .binary_operator);
    try testing.expectEqual(@as(u8, '+'), expr.binary_operator.value);

    try testing.expect(expr.binary_operator.lhs.?.* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.binary_operator.lhs.?.constant.number);

    try testing.expect(expr.binary_operator.rhs.?.* == .binary_operator);
    try testing.expectEqual(@as(u8, '*'), expr.binary_operator.rhs.?.binary_operator.value);
}

test "parse let statement" {
    const allocator = testing.allocator;
    const src = "let x = 42;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .let);
    try testing.expectEqualStrings("x", statement.let.name);
    try testing.expect(statement.let.value.* == .constant);
    try testing.expectEqual(@as(f64, 42), statement.let.value.constant.number);
}

test "parse expression statement" {
    const allocator = testing.allocator;
    const src = "x + 5;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .expression);
    try testing.expect(statement.expression.expression.* == .binary_operator);
    try testing.expectEqual(@as(u8, '+'), statement.expression.expression.binary_operator.value);
}

test "parse block statement" {
    const allocator = testing.allocator;
    const src = "{ let x = 1; let y = 2; }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .block);
    try testing.expectEqual(@as(usize, 2), statement.block.statements.items.len);

    try testing.expect(statement.block.statements.items[0].* == .let);
    try testing.expectEqualStrings("x", statement.block.statements.items[0].let.name);

    try testing.expect(statement.block.statements.items[1].* == .let);
    try testing.expectEqualStrings("y", statement.block.statements.items[1].let.name);
}

test "declare an empty function" {
    const src = "fn test() { }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try testing.expect(interpreter.functions.get("test") != null);
}

test "parse function declaration with parameters" {
    const src = "fn add(a, b) { ret a + b; }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);

    const func = interpreter.functions.get("add");
    try testing.expect(func != null);
    try testing.expectEqualStrings("add", func.?.name);
    try testing.expectEqual(@as(usize, 2), func.?.parameters.items.len);
    try testing.expectEqualStrings("a", func.?.parameters.items[0]);
    try testing.expectEqualStrings("b", func.?.parameters.items[1]);
}

test "parse return statement with value" {
    const allocator = testing.allocator;
    const src = "ret 123;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .ret);
    try testing.expect(statement.ret.value != null);
    try testing.expect(statement.ret.value.?.* == .constant);
    try testing.expectEqual(@as(f64, 123), statement.ret.value.?.constant.number);
}

test "parse if statement" {
    const allocator = testing.allocator;
    const src = "if x > 5 { ret x; }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .if_cond);
    try testing.expect(statement.if_cond.condition.* == .comparison_operator);
    try testing.expectEqualStrings(">", statement.if_cond.condition.comparison_operator.op);

    try testing.expectEqual(@as(usize, 1), statement.if_cond.body.statements.items.len);
    try testing.expect(statement.if_cond.body.statements.items[0].* == .ret);
}

test "parse empty block" {
    const allocator = testing.allocator;
    const src = "{ }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .block);
    try testing.expectEqual(@as(usize, 0), statement.block.statements.items.len);
}

test "parse nested blocks" {
    const allocator = testing.allocator;
    const src = "{ { let x = 1; } }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const statement = program.statements.items[0];
    try testing.expect(statement.* == .block);
    try testing.expectEqual(@as(usize, 1), statement.block.statements.items.len);
    try testing.expect(statement.block.statements.items[0].* == .block);
    try testing.expectEqual(@as(usize, 1), statement.block.statements.items[0].block.statements.items.len);
}

test "parse function with no body statements" {
    const src = "fn empty() { }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);

    const func = interpreter.functions.get("empty");
    try testing.expect(func != null);
    try testing.expectEqualStrings("empty", func.?.name);
    try testing.expectEqual(@as(usize, 0), func.?.parameters.items.len);
    try testing.expectEqual(@as(usize, 0), func.?.block.statements.items.len);
}

test "parse chained function calls" {
    const allocator = testing.allocator;
    const src = "outer(inner(42));";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .function_call);
    try testing.expectEqualStrings("outer", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 1), expr.function_call.parameters.items.len);

    try testing.expect(expr.function_call.parameters.items[0].* == .function_call);
    try testing.expectEqualStrings("inner", expr.function_call.parameters.items[0].function_call.function_name);
}

test "parse an array" {
    const allocator = testing.allocator;
    const src = "[1, 2, 3];";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;
    try testing.expect(expr.* == .constant);
    try testing.expect(expr.constant == .array);
    try testing.expectEqual(@as(usize, 3), expr.constant.array.items.len);

    try testing.expect(expr.constant.array.items[0].* == .constant);
    try testing.expectEqual(@as(f64, 1), expr.constant.array.items[0].constant.number);

    try testing.expect(expr.constant.array.items[1].* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.constant.array.items[1].constant.number);

    try testing.expect(expr.constant.array.items[2].* == .constant);
    try testing.expectEqual(@as(f64, 3), expr.constant.array.items[2].constant.number);
}
