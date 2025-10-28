const std = @import("std");
const testing = std.testing;
const mylang = @import("mylang");

test "lexer basic tokens" {
    var lexer = mylang.Lexer.init("+ - * / = == != > >= < <= ( ) { } [ ] ; ,");

    try testing.expect(lexer.next() == .plus);
    try testing.expect(lexer.next() == .minus);
    try testing.expect(lexer.next() == .asterisk);
    try testing.expect(lexer.next() == .slash);
    try testing.expect(lexer.next() == .assign);
    try testing.expect(lexer.next() == .eq);
    try testing.expect(lexer.next() == .noteq);
    try testing.expect(lexer.next() == .greater);
    try testing.expect(lexer.next() == .greatereq);
    try testing.expect(lexer.next() == .less);
    try testing.expect(lexer.next() == .lesseq);
    try testing.expect(lexer.next() == .lparen);
    try testing.expect(lexer.next() == .rparen);
    try testing.expect(lexer.next() == .lbrace);
    try testing.expect(lexer.next() == .rbrace);
    try testing.expect(lexer.next() == .sq_lbracket);
    try testing.expect(lexer.next() == .sq_rbracket);
    try testing.expect(lexer.next() == .semicolon);
    try testing.expect(lexer.next() == .comma);
    try testing.expect(lexer.next() == .eof);
}

test "lexer keywords" {
    var lexer = mylang.Lexer.init("let fn ret true false if");

    try testing.expect(lexer.next() == .let);
    try testing.expect(lexer.next() == .function);
    try testing.expect(lexer.next() == .ret);
    try testing.expect(lexer.next() == .true_literal);
    try testing.expect(lexer.next() == .false_literal);
    try testing.expect(lexer.next() == .if_cond);
    try testing.expect(lexer.next() == .eof);
}

test "lexer identifiers and numbers" {
    var lexer = mylang.Lexer.init("variable 42 55.5");

    const ident = lexer.next();
    try testing.expect(ident == .ident);
    try testing.expectEqualStrings("variable", ident.ident);

    const num1 = lexer.next();
    try testing.expect(num1 == .number);
    try testing.expectEqual(@as(f64, 42), num1.number);

    const num2 = lexer.next();
    try testing.expect(num2 == .number);
    try testing.expectEqual(@as(f64, 55.5), num2.number);

    try testing.expect(lexer.next() == .eof);
}

test "lexer string literals" {
    var lexer = mylang.Lexer.init("\"hello world\"");

    const str = lexer.next();
    try testing.expect(str == .string);
    try testing.expectEqualStrings("hello world", str.string);

    try testing.expect(lexer.next() == .eof);
}

test "lexer addition expression" {
    var lexer = mylang.Lexer.init("5 + 5");

    const num1 = lexer.next();
    try testing.expect(num1 == .number);
    try testing.expectEqual(@as(f64, 5), num1.number);

    try testing.expect(lexer.next() == .plus);

    const num2 = lexer.next();
    try testing.expect(num2 == .number);
    try testing.expectEqual(@as(f64, 5), num2.number);

    try testing.expect(lexer.next() == .eof);
}

test "lexer multidigit number" {
    var lexer = mylang.Lexer.init("55");

    const num = lexer.next();
    try testing.expect(num == .number);
    try testing.expectEqual(@as(f64, 55), num.number);

    try testing.expect(lexer.next() == .eof);
}

test "lexer addition no spaces" {
    var lexer = mylang.Lexer.init("5+55");

    const num1 = lexer.next();
    try testing.expect(num1 == .number);
    try testing.expectEqual(@as(f64, 5), num1.number);

    try testing.expect(lexer.next() == .plus);

    const num2 = lexer.next();
    try testing.expect(num2 == .number);
    try testing.expectEqual(@as(f64, 55), num2.number);

    try testing.expect(lexer.next() == .eof);
}

test "lexer parentheses expression" {
    var lexer = mylang.Lexer.init("2 * (5 + 5)");

    const num1 = lexer.next();
    try testing.expect(num1 == .number);
    try testing.expectEqual(@as(f64, 2), num1.number);

    try testing.expect(lexer.next() == .asterisk);
    try testing.expect(lexer.next() == .lparen);

    const num2 = lexer.next();
    try testing.expect(num2 == .number);
    try testing.expectEqual(@as(f64, 5), num2.number);

    try testing.expect(lexer.next() == .plus);

    const num3 = lexer.next();
    try testing.expect(num3 == .number);
    try testing.expectEqual(@as(f64, 5), num3.number);

    try testing.expect(lexer.next() == .rparen);
    try testing.expect(lexer.next() == .eof);
}

test "lexer factorial" {
    var lexer = mylang.Lexer.init("5!");

    const num = lexer.next();
    try testing.expect(num == .number);
    try testing.expectEqual(@as(f64, 5), num.number);

    try testing.expect(lexer.next() == .bang);
    try testing.expect(lexer.next() == .eof);
}

test "lexer whitespace handling" {
    var lexer = mylang.Lexer.init("  \t\r let   \n  ");

    try testing.expect(lexer.next() == .let);
    try testing.expect(lexer.next() == .eol);
    try testing.expect(lexer.next() == .eof);
}

test "lexer empty input" {
    var lexer = mylang.Lexer.init("");

    try testing.expect(lexer.next() == .eof);
}

test "lexer illegal characters" {
    var lexer = mylang.Lexer.init("@#$");

    try testing.expect(lexer.next() == .illegal);
    try testing.expect(lexer.next() == .illegal);
    try testing.expect(lexer.next() == .illegal);
    try testing.expect(lexer.next() == .eof);
}

test "lexer operator precedence tokens" {
    var lexer = mylang.Lexer.init("! != == = < <= > >=");

    try testing.expect(lexer.next() == .bang);
    try testing.expect(lexer.next() == .noteq);
    try testing.expect(lexer.next() == .eq);
    try testing.expect(lexer.next() == .assign);
    try testing.expect(lexer.next() == .less);
    try testing.expect(lexer.next() == .lesseq);
    try testing.expect(lexer.next() == .greater);
    try testing.expect(lexer.next() == .greatereq);
    try testing.expect(lexer.next() == .eof);
}

test "lexer complex expression" {
    var lexer = mylang.Lexer.init("let result = func(x, y) + 42;");

    try testing.expect(lexer.next() == .let);

    const ident1 = lexer.next();
    try testing.expect(ident1 == .ident);
    try testing.expectEqualStrings("result", ident1.ident);

    try testing.expect(lexer.next() == .assign);

    const ident2 = lexer.next();
    try testing.expect(ident2 == .ident);
    try testing.expectEqualStrings("func", ident2.ident);

    try testing.expect(lexer.next() == .lparen);

    const ident3 = lexer.next();
    try testing.expect(ident3 == .ident);
    try testing.expectEqualStrings("x", ident3.ident);

    try testing.expect(lexer.next() == .comma);

    const ident4 = lexer.next();
    try testing.expect(ident4 == .ident);
    try testing.expectEqualStrings("y", ident4.ident);

    try testing.expect(lexer.next() == .rparen);
    try testing.expect(lexer.next() == .plus);

    const num = lexer.next();
    try testing.expect(num == .number);
    try testing.expectEqual(@as(f64, 42), num.number);

    try testing.expect(lexer.next() == .semicolon);
    try testing.expect(lexer.next() == .eof);
}

test "lexer string with spaces" {
    var lexer = mylang.Lexer.init("\"hello world with spaces\"");

    const str = lexer.next();
    try testing.expect(str == .string);
    try testing.expectEqualStrings("hello world with spaces", str.string);

    try testing.expect(lexer.next() == .eof);
}

test "lexer multiple strings" {
    var lexer = mylang.Lexer.init("\"first\" + \"second\"");

    const str1 = lexer.next();
    try testing.expect(str1 == .string);
    try testing.expectEqualStrings("first", str1.string);

    try testing.expect(lexer.next() == .plus);

    const str2 = lexer.next();
    try testing.expect(str2 == .string);
    try testing.expectEqualStrings("second", str2.string);

    try testing.expect(lexer.next() == .eof);
}
