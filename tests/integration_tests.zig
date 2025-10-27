const std = @import("std");
const testing = std.testing;
const mylang = @import("mylang");

fn createParser(allocator: std.mem.Allocator, source: []const u8) mylang.Parser {
    const lexer = mylang.Lexer.init(source);
    return mylang.Parser.init(lexer, allocator);
}

fn expectExpressionType(allocator: std.mem.Allocator, source: []const u8, expected_type: std.meta.Tag(mylang.Expression)) !*mylang.Expression {
    var parser = createParser(allocator, source);
    const expr = try parser.parseExpression();
    try testing.expect(@as(std.meta.Tag(mylang.Expression), expr.*) == expected_type);
    return expr;
}

fn expectStatementType(allocator: std.mem.Allocator, source: []const u8, expected_type: std.meta.Tag(mylang.Statement)) !*mylang.Statement {
    var parser = createParser(allocator, source);
    const statement = (try parser.parseStatement()).?;
    try testing.expect(@as(std.meta.Tag(mylang.Statement), statement.*) == expected_type);
    return statement;
}

test "nested function calls in expressions" {
    const src =
        \\fn add(a, b) { ret a + b; }
        \\fn multiply(x, y) { ret x * y; }
        \\let result = multiply(add(2, 3), add(4, 5));
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    try std.testing.expect(program.getFunction("add") != null);
    try std.testing.expect(program.getFunction("multiply") != null);

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

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const func = program.getFunction("factorial");
    try std.testing.expect(func != null);
    try testing.expectEqualStrings("factorial", func.?.name);
    try testing.expectEqual(@as(usize, 1), func.?.parameters.items.len);
    try testing.expectEqual(@as(usize, 2), program.statements.items.len);
}

test "parse complex nested expression" {
    const allocator = testing.allocator;

    var parser = createParser(allocator, "(a + b) * (c - d) / 2");
    const expr = try parser.parseExpression();
    defer {
        expr.deinit(allocator);
        allocator.destroy(expr);
    }

    try testing.expect(expr.* == .binary_operator);
    try testing.expectEqual(@as(u8, '/'), expr.binary_operator.value);

    try testing.expect(expr.binary_operator.lhs.?.* == .binary_operator);
    try testing.expectEqual(@as(u8, '*'), expr.binary_operator.lhs.?.binary_operator.value);

    try testing.expect(expr.binary_operator.rhs.?.* == .constant);
    try testing.expectEqual(@as(f64, 2), expr.binary_operator.rhs.?.constant.value.number);
}

// FREEZES
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
//     var program = try mylang.createInterpreter(std.testing.allocator, src);
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//
//     try program.execute();
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
//
//     var parser = createParser(allocator, "let + 5");
//     try testing.expectError(mylang.ParseError.ExpectedIdentifier, parser.parseStatement());
// }
//
// test "parse error - missing assignment" {
//     const allocator = testing.allocator;
//
//     var parser = createParser(allocator, "let x 5");
//     try testing.expectError(mylang.ParseError.ExpectedAssignment, parser.parseStatement());
// }
//
// test "parse error - missing closing brace" {
//     const allocator = testing.allocator;
//
//     var parser = createParser(allocator, "{ let x = 5;");
//     try testing.expectError(mylang.ParseError.UnexpectedEOF, parser.parseStatement());
// }
//
// test "parse error - missing closing parenthesis in function call" {
//     const allocator = testing.allocator;
//
//     var parser = createParser(allocator, "println(42");
//     try testing.expectError(mylang.ParseError.ExpectedCommaOrRParen, parser.parseExpression());
// }
//
// test "parse error - invalid prefix operator" {
//     const allocator = testing.allocator;
//
//     var parser = createParser(allocator, "* 5");
//     try testing.expectError(mylang.ParseError.ParseError, parser.parseExpression());
// }
