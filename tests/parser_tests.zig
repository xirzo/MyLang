const std = @import("std");
const testing = std.testing;
const mylang = @import("mylang");

fn expectExpressionType(allocator: std.mem.Allocator, source: []const u8, expected_type: std.meta.Tag(mylang.Expression)) !*mylang.Expression {
    const lexer = mylang.Lexer.init(source);
    var parser = mylang.Parser.init(lexer, allocator);
    const expr = try parser.parseExpression();
    try testing.expect(@as(std.meta.Tag(mylang.Expression), expr.*) == expected_type);
    return expr;
}

fn expectStatementType(allocator: std.mem.Allocator, source: []const u8, expected_type: std.meta.Tag(mylang.Statement)) !*mylang.Statement {
    const lexer = mylang.Lexer.init(source);
    var parser = mylang.Parser.init(lexer, allocator);
    const statement = (try parser.parseStatement()).?;
    try testing.expect(@as(std.meta.Tag(mylang.Statement), statement.*) == expected_type);
    return statement;
}

test "parse number literal" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "42", .constant);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.constant.value == .number);
    try testing.expectEqual(@as(f64, 42), expr.constant.value.number);
}

test "parse number literal with dot" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "3.14", .constant);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.constant.value == .number);
    try testing.expectEqual(@as(f64, 3.14), expr.constant.value.number);
}

test "parse string literal" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "\"hello world\"", .constant);

    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.constant.value == .string);
    try testing.expectEqualStrings("hello world", expr.constant.value.string);
}

test "parse trueliteral" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "true", .constant);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.constant.value == .boolean);
    try testing.expect(expr.constant.value.boolean == true);
}

test "parse false literal" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "false", .constant);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.constant.value == .boolean);
    try testing.expect(expr.constant.value.boolean == false);
}

test "parse variable reference" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "myVariable", .variable);

    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqualStrings("myVariable", expr.variable.name);
}

test "parse function call without parameters" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "println()", .function_call);

    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqualStrings("println", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 0), expr.function_call.parameters.items.len);
}

test "parse function call with parameters" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "add(1, 2, x)", .function_call);

    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqualStrings("add", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 3), expr.function_call.parameters.items.len);

    try testing.expect(expr.function_call.parameters.items[0].* == .constant);
    try testing.expectEqual(@as(f64, 1), expr.function_call.parameters.items[0].constant.value.number);

    try testing.expect(expr.function_call.parameters.items[1].* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.function_call.parameters.items[1].constant.value.number);

    try testing.expect(expr.function_call.parameters.items[2].* == .variable);
    try testing.expectEqualStrings("x", expr.function_call.parameters.items[2].variable.name);
}

test "parse binary operators" {
    const allocator = testing.allocator;

    const test_cases = [_]struct { source: []const u8, op: u8 }{
        .{ .source = "1 + 2", .op = '+' },
        .{ .source = "5 - 3", .op = '-' },
        .{ .source = "4 * 6", .op = '*' },
        .{ .source = "8 / 2", .op = '/' },
    };

    for (test_cases) |case| {
        const expr = try expectExpressionType(allocator, case.source, .binary_operator);

        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        try testing.expectEqual(case.op, expr.binary_operator.value);
        try testing.expect(expr.binary_operator.lhs != null);
        try testing.expect(expr.binary_operator.rhs != null);
    }
}

// test "parse comparison operators" {
//     const allocator = testing.allocator;
//
//     const test_cases = [_]struct { source: []const u8, op: mylang.Lexeme }{
//         .{ .source = "a == b", .op = .eq },
//         .{ .source = "x != y", .op = .noteq },
//         .{ .source = "5 > 3", .op = .greater },
//         .{ .source = "10 >= 5", .op = .greatereq },
//         .{ .source = "2 < 8", .op = .less },
//         .{ .source = "7 <= 9", .op = .lesseq },
//     };
//
//     for (test_cases) |case| {
//         const expr = try expectExpressionType(allocator, case.source, .comparison_operator);
//
//         defer {
//             expr.deinit(allocator);
//             allocator.destroy(expr);
//         }
//
//         try testing.expectEqual(case.op, expr.comparison_operator.op);
//         try testing.expect(expr.comparison_operator.lhs != null);
//         try testing.expect(expr.comparison_operator.rhs != null);
//     }
// }

test "parse unary prefix operators" {
    const allocator = testing.allocator;

    const test_cases = [_]struct { source: []const u8, op: u8 }{
        .{ .source = "+5", .op = '+' },
        .{ .source = "-10", .op = '-' },
    };

    for (test_cases) |case| {
        const expr = try expectExpressionType(allocator, case.source, .binary_operator);
        defer {
            expr.deinit(allocator);
            allocator.destroy(expr);
        }

        try testing.expectEqual(case.op, expr.binary_operator.value);
        try testing.expect(expr.binary_operator.lhs == null);
        try testing.expect(expr.binary_operator.rhs != null);
    }
}

test "parse postfix operators" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "x!", .binary_operator);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqual(@as(u8, '!'), expr.binary_operator.value);
    try testing.expect(expr.binary_operator.lhs != null);
    try testing.expect(expr.binary_operator.rhs == null);
}

test "parse parenthesized expressions" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "(42)", .constant);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqual(@as(f64, 42), expr.constant.value.number);
}

test "operator precedence" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "2 + 3 * 4", .binary_operator);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqual(@as(u8, '+'), expr.binary_operator.value);

    try testing.expect(expr.binary_operator.lhs.?.* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.binary_operator.lhs.?.constant.value.number);

    try testing.expect(expr.binary_operator.rhs.?.* == .binary_operator);
    try testing.expectEqual(@as(u8, '*'), expr.binary_operator.rhs.?.binary_operator.value);
}

test "parse let statement" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "let x = 42", .let);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expectEqualStrings("x", statement.let.name);
    try testing.expect(statement.let.value.* == .constant);
    try testing.expectEqual(@as(f64, 42), statement.let.value.constant.value.number);
}

test "parse expression statement" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "x + 5", .expression);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expect(statement.expression.expression.* == .binary_operator);
    try testing.expectEqual(@as(u8, '+'), statement.expression.expression.binary_operator.value);
}

test "parse block statement" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "{ let x = 1; let y = 2; }", .block);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expectEqual(@as(usize, 2), statement.block.statements.items.len);

    try testing.expect(statement.block.statements.items[0].* == .let);
    try testing.expectEqualStrings("x", statement.block.statements.items[0].let.name);

    try testing.expect(statement.block.statements.items[1].* == .let);
    try testing.expectEqualStrings("y", statement.block.statements.items[1].let.name);
}

test "declare an empty function" {
    const src =
        \\ fn test() { }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    try std.testing.expect(program.getFunction("test") != null);
}

test "parse function declaration with parameters" {
    const src =
        \\ fn add(a, b) { ret a + b; }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const func = program.getFunction("add");
    try std.testing.expect(func != null);
    try std.testing.expectEqualStrings("add", func.?.name);
    try testing.expectEqual(@as(usize, 2), func.?.parameters.items.len);
    try testing.expectEqualStrings("a", func.?.parameters.items[0]);
    try testing.expectEqualStrings("b", func.?.parameters.items[1]);
}

test "parse return statement with value" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "ret 123", .ret);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expect(statement.ret.value != null);
    try testing.expect(statement.ret.value.?.* == .constant);
    try testing.expectEqual(@as(f64, 123), statement.ret.value.?.constant.value.number);
}

test "parse if statement" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "if x > 5 { ret x; }", .if_cond);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expect(statement.if_cond.condition.* == .comparison_operator);
    try testing.expectEqual(">", statement.if_cond.condition.comparison_operator.op);

    try testing.expectEqual(@as(usize, 1), statement.if_cond.body.statements.items.len);
    try testing.expect(statement.if_cond.body.statements.items[0].* == .ret);
}

test "parse empty block" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "{ }", .block);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expectEqual(@as(usize, 0), statement.block.statements.items.len);
}

test "parse nested blocks" {
    const allocator = testing.allocator;

    const statement = try expectStatementType(allocator, "{ { let x = 1; } }", .block);
    defer {
        statement.deinit(allocator);
        allocator.destroy(statement);
    }

    try testing.expectEqual(@as(usize, 1), statement.block.statements.items.len);
    try testing.expect(statement.block.statements.items[0].* == .block);
    try testing.expectEqual(@as(usize, 1), statement.block.statements.items[0].block.statements.items.len);
}

test "parse function with no body statements" {
    const src =
        \\ fn empty() { }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const func = program.getFunction("empty");
    try std.testing.expect(func != null);
    try testing.expectEqualStrings("empty", func.?.name);
    try testing.expectEqual(@as(usize, 0), func.?.parameters.items.len);
    try testing.expectEqual(@as(usize, 0), func.?.block.statements.items.len);
}

test "parse chained function calls" {
    const allocator = testing.allocator;

    const expr = try expectExpressionType(allocator, "outer(inner(42))", .function_call);
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expectEqualStrings("outer", expr.function_call.function_name);
    try testing.expectEqual(@as(usize, 1), expr.function_call.parameters.items.len);

    try testing.expect(expr.function_call.parameters.items[0].* == .function_call);
    try testing.expectEqualStrings("inner", expr.function_call.parameters.items[0].function_call.function_name);
}
