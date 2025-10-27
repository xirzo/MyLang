const std = @import("std");
const mylang = @import("mylang");

test "lex assignment" {
    const src = "int a = 123;";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .ident = "int" });
    try expected.append(mylang.Lexeme{ .ident = "a" });
    try expected.append(mylang.Lexeme{ .assign = '=' });
    try expected.append(mylang.Lexeme{ .number = 123 });
    try expected.append(mylang.Lexeme{ .semicolon = ';' });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

test "lex addition" {
    const src = "5 + 5";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .plus = '+' });
    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

test "lex multidigit number" {
    const src = "55";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .number = 55 });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

test "lex addition no spaces" {
    const src = "5+55";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .plus = '+' });
    try expected.append(mylang.Lexeme{ .number = 55 });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

test "lex paren" {
    const src = "2 * (5 + 5)";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .number = 2 });
    try expected.append(mylang.Lexeme{ .asterisk = '*' });
    try expected.append(mylang.Lexeme{ .lparen = '(' });
    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .plus = '+' });
    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .rparen = ')' });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

test "lex factorial" {
    const src = "5!";
    var lexer = mylang.Lexer.init(src);

    var expected = std.array_list.Managed(mylang.Lexeme).init(std.testing.allocator);
    defer expected.deinit();

    try expected.append(mylang.Lexeme{ .number = 5 });
    try expected.append(mylang.Lexeme{ .bang = '!' });
    try expected.append(mylang.Lexeme{ .eof = {} });

    for (expected.items) |exp_token| {
        const actual_token = lexer.next();

        try std.testing.expectEqual(@as(std.meta.Tag(mylang.Lexeme), exp_token), @as(std.meta.Tag(mylang.Lexeme), actual_token));
        try expect_lexeme_equal(exp_token, actual_token);
    }
}

fn expect_lexeme_equal(expected: mylang.Lexeme, actual: mylang.Lexeme) !void {
    const tag_expected = @as(std.meta.Tag(mylang.Lexeme), expected);
    const tag_actual = @as(std.meta.Tag(mylang.Lexeme), actual);
    try std.testing.expectEqual(tag_expected, tag_actual);

    switch (tag_expected) {
        .ident => try std.testing.expectEqualStrings(expected.ident, actual.ident),
        .assign => try std.testing.expectEqual(expected.assign, actual.assign),
        .number => try std.testing.expectEqual(expected.number, actual.number),
        .semicolon => try std.testing.expectEqual(expected.semicolon, actual.semicolon),
        .plus => try std.testing.expectEqual(expected.plus, actual.plus),
        .asterisk => try std.testing.expectEqual(expected.asterisk, actual.asterisk),
        .minus => try std.testing.expectEqual(expected.minus, actual.minus),
        .slash => try std.testing.expectEqual(expected.slash, actual.slash),
        .eof => try std.testing.expectEqual(expected.eof, actual.eof),
        .lparen => try std.testing.expectEqual(expected.lparen, actual.lparen),
        .rparen => try std.testing.expectEqual(expected.rparen, actual.rparen),
        .bang => try std.testing.expectEqual(expected.bang, actual.bang),
        .string => try std.testing.expectEqual(expected.string, actual.string),
        .lbrace => try std.testing.expectEqual(expected.lbrace, actual.lbrace),
        .rbrace => try std.testing.expectEqual(expected.rbrace, actual.rbrace),
        .comma => try std.testing.expectEqual(expected.comma, actual.comma),
        .let => try std.testing.expectEqual(expected.let, actual.let),
        .function => try std.testing.expectEqual(expected.function, actual.function),
        .ret => try std.testing.expectEqual(expected.ret, actual.ret),
        .eq => try std.testing.expectEqual(expected.eq, actual.eq),
        .noteq => try std.testing.expectEqual(expected.noteq, actual.noteq),
        .greater => try std.testing.expectEqual(expected.greater, actual.greater),
        .greatereq => try std.testing.expectEqual(expected.greatereq, actual.greatereq),
        .less => try std.testing.expectEqual(expected.less, actual.less),
        .lesseq => try std.testing.expectEqual(expected.lesseq, actual.lesseq),
        .true_literal => try std.testing.expectEqual(expected.true_literal, actual.true_literal),
        .false_literal => try std.testing.expectEqual(expected.false_literal, actual.false_literal),
        .if_cond => try std.testing.expectEqual(expected.if_cond, actual.if_cond),
        .eol => try std.testing.expectEqual(expected.eol, actual.eol),
        .illegal => {},
    }
}
