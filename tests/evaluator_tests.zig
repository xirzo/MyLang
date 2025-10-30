const std = @import("std");
const mylang = @import("mylang");

test "evaluate arithmetic program" {
    const src = "let x = 5 + 5;";
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);

    try std.testing.expectEqual(10.0, interpreter.environment.get("x").?.number);
}

test "evaluate complex arithmetic program" {
    const src = "let x = 5 + 5 * 2;";
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(15.0, interpreter.environment.get("x").?.number);
}

test "evaluate parentheses program" {
    const src = "let x = (5 + 5) * 2;";
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(20.0, interpreter.environment.get("x").?.number);
}

test "evaluate substraction" {
    const src = "let x = 0 - 5;";
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(-5.0, interpreter.environment.get("x").?.number);
}

test "evaluate array ith element" {
    const src = "let x = [1, 2, 3];";
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(1.0, interpreter.environment.get("x").?.array.items[0].number);
}

test "evaluate arrays concat" {
    const src =
        \\ let x = [1, 2, 3];
        \\ let y = [4, 5, 6];
        \\ let z = x + y;
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(6, interpreter.environment.get("z").?.array.items.len);
}

test "evaluate object" {
    const src =
        \\ let x = {
        \\   a = 1,
        \\   b = 2,
        \\   c = 3
        \\ };
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expect(interpreter.environment.get("x").? == .object);
}

test "evaluate object item access" {
    const src =
        \\ let y = {
        \\   a = 1,
        \\   b = 2,
        \\   c = 3
        \\ };
        \\
        \\ let x = y.a;
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(1.0, interpreter.environment.get("x").?.number);
}

test "evaluate while loop" {
    const src =
        \\ let x = 0;
        \\
        \\ while x < 5 {
        \\   x = x + 1;
        \\ }
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(5.0, interpreter.environment.get("x").?.number);
}

test "evaluate for loop" {
    const src =
        \\ for let x = 1; x < 5; x = x  + 1 { }
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(5.0, interpreter.environment.get("x").?.number);
}

test "variable reassignment" {
    const src =
        \\ let x = 5;
        \\ x = x + 5;
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(10.0, interpreter.environment.get("x").?.number);
}

test "strlen" {
    const src =
        \\ let str = "Hello, World!";
        \\ let x = strlen(str);
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(13, interpreter.environment.get("x").?.number);
}

test "get ith char of string" {
    const src =
        \\ let str = "Hello, World!";
        \\ let x = str[5];
    ;
    const lexer = mylang.Lexer.init(src);
    var parser = mylang.Parser.init(std.testing.allocator, lexer);
    const program = try parser.parse();
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }
    var interpreter = try mylang.Interpreter.init(std.testing.allocator);
    defer interpreter.deinit();

    try interpreter.execute(program);
    try std.testing.expectEqual(',', interpreter.environment.get("x").?.char);
}
