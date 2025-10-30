const std = @import("std");
const testing = std.testing;
const mylang = @import("mylang");

test "nested function calls in expressions" {
    const src =
        \\fn add(a, b) { ret a + b; }
        \\fn multiply(x, y) { ret x * y; }
        \\let result = multiply(add(2, 3), add(4, 5));
    ;

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

    try testing.expect(interpreter.functions.get("add") != null);
    try testing.expect(interpreter.functions.get("multiply") != null);

    try testing.expectEqual(@as(usize, 3), program.statements.items.len);
}

test "factorial calculation" {
    const src =
        \\fn factorial(n) {
        \\    if n <= 1 {
        \\        ret 1;
        \\    }
        \\    ret n * factorial(n - 1);
        \\}
        \\
        \\let result = factorial(2);
    ;

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

    const func = interpreter.functions.get("factorial");
    try testing.expect(func != null);
    try testing.expectEqualStrings("factorial", func.?.name);
    try testing.expectEqual(@as(usize, 1), func.?.parameters.items.len);
    try testing.expectEqual(@as(usize, 2), program.statements.items.len);
}

test "parse complex nested expression" {
    const allocator = testing.allocator;
    const src = "(a + b) * (c - d) / 2;";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    const expr = program.statements.items[0].expression.expression;

    try testing.expect(expr.* == .binary_operator);
    try testing.expectEqual(@as(u8, '/'), expr.binary_operator.value);

    try testing.expect(expr.binary_operator.lhs.?.* == .binary_operator);
    try testing.expectEqual(@as(u8, '*'), expr.binary_operator.lhs.?.binary_operator.value);

    try testing.expect(expr.binary_operator.rhs.?.* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.binary_operator.rhs.?.constant.number);
}

//FIX: FREEZES
// test "parse program with mixed statements" {
//     const src =
//         \\let x = 10;
//         \\fn double(n) {
//         \\    ret n * 2;
//         \\}
//         \\if x > 5 {
//         \\    println("x is large");
//         \\}
//     ;
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(testing.allocator, lexer);
//     const program = try parser.parse();
//     defer {
//         program.deinit();
//         testing.allocator.destroy(program);
//     }
//     var interpreter = try mylang.Interpreter.init(testing.allocator);
//     defer interpreter.deinit();
//
//     try interpreter.execute(program);
//
//     try testing.expectEqual(@as(usize, 3), program.statements.items.len);
//
//     try testing.expect(program.statements.items[0].* == .let);
//     try testing.expectEqualStrings("x", program.statements.items[0].let.name);
//
//     try testing.expect(program.statements.items[1].* == .function_declaration);
//     try testing.expectEqualStrings("double", program.statements.items[1].function_declaration.name);
//
//     try testing.expect(program.statements.items[2].* == .if_cond);
// }

// test "parse error - unexpected token" {
//     const allocator = testing.allocator;
//     const src = "let + 5;";
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(allocator, lexer);
//
//     try testing.expectError(mylang.ParseError.ExpectedIdentifier, parser.parse());
// }
//
// test "parse error - missing assignment" {
//     const allocator = testing.allocator;
//     const src = "let x 5;";
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(allocator, lexer);
//
//     try testing.expectError(mylang.ParseError.ExpectedAssignment, parser.parse());
// }
//
// test "parse error - missing closing brace" {
//     const allocator = testing.allocator;
//     const src = "{ let x = 5;";
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(allocator, lexer);
//
//     try testing.expectError(mylang.ParseError.UnexpectedEOF, parser.parse());
// }
//
// test "parse error - missing closing parenthesis in function call" {
//     const allocator = testing.allocator;
//     const src = "println(42;";
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(allocator, lexer);
//
//     try testing.expectError(mylang.ParseError.ExpectedCommaOrRParen, parser.parse());
// }
//
// test "parse error - invalid prefix operator" {
//     const allocator = testing.allocator;
//     const src = "* 5;";
//
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(allocator, lexer);
//
//     try testing.expectError(mylang.ParseError.ParseError, parser.parse());
// }

test "parse array with nested expressions" {
    const allocator = testing.allocator;
    const src = "[1 + 2, 3 * 4, x];";

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

    try testing.expect(expr.constant.array.items[0].* == .binary_operator);
    try testing.expectEqual(@as(u8, '+'), expr.constant.array.items[0].binary_operator.value);

    try testing.expect(expr.constant.array.items[1].* == .binary_operator);
    try testing.expectEqual(@as(u8, '*'), expr.constant.array.items[1].binary_operator.value);

    try testing.expect(expr.constant.array.items[2].* == .variable);
    try testing.expectEqualStrings("x", expr.constant.array.items[2].variable.name);
}

test "parse multiple assignment statements" {
    const allocator = testing.allocator;
    const src =
        \\let a = 1;
        \\let b = 2;
        \\a = a + b;
        \\b = a * 2;
    ;

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    try testing.expectEqual(@as(usize, 4), program.statements.items.len);

    // First two should be let statements
    try testing.expect(program.statements.items[0].* == .let);
    try testing.expectEqualStrings("a", program.statements.items[0].let.name);

    try testing.expect(program.statements.items[1].* == .let);
    try testing.expectEqualStrings("b", program.statements.items[1].let.name);

    // Last two should be assignment statements
    try testing.expect(program.statements.items[2].* == .assignment);
    try testing.expectEqualStrings("a", program.statements.items[2].assignment.name);

    try testing.expect(program.statements.items[3].* == .assignment);
    try testing.expectEqualStrings("b", program.statements.items[3].assignment.name);
}

test "parse for loop with initialization and increment" {
    const allocator = testing.allocator;
    const src = "for let i = 0; i < 10; i = i + 1 { println(i); }";

    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        allocator.destroy(program);
    }

    try testing.expectEqual(@as(usize, 1), program.statements.items.len);
    try testing.expect(program.statements.items[0].* == .for_loop);

    const for_stmt = &program.statements.items[0].for_loop;

    try testing.expect(for_stmt.condition.* == .comparison_operator);

    try testing.expect(for_stmt.increment.* == .assignment);

    try testing.expectEqual(@as(usize, 1), for_stmt.body.statements.items.len);
    try testing.expect(for_stmt.body.statements.items[0].* == .expression);
}
