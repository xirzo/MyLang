const std = @import("std");
const mylang = @import("mylang");

test "evaluate arithmetic program" {
    const src = "let x = 5 + 5;";

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(10.0, program.environment.get("x").?.number);
}

test "evaluate complex arithmetic program" {
    const src = "let x = 5 + 5 * 2;";

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(15.0, program.environment.get("x").?.number);
}

test "evaluate parentheses program" {
    const src = "let x = (5 + 5) * 2;";

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(20.0, program.environment.get("x").?.number);
}

test "evaluate substraction" {
    const src = "let x = 0 - 5;";

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();
    try std.testing.expectEqual(-5.0, program.environment.get("x").?.number);
}

test "evaluate array ith element" {
    const src = "let x = [1, 2, 3];";

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }

    try program.execute();
    try std.testing.expectEqual(1.0, program.environment.get("x").?.array.items[0].number);
}

test "evaluate arrays concat" {
    const src =
        \\ let x = [1, 2, 3];
        \\ let y = [4, 5, 6];
        \\ let z = x + y;
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }

    try program.execute();
    try std.testing.expectEqual(6, program.environment.get("z").?.array.items.len);
}

// test "evaluate an array" {
//     const src = "let x = [1, 2, 3];";
//
//     var program = try mylang.createInterpreter(std.testing.allocator, src);
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//     var expected = std.array_list.Managed(mylang.Value).init(std.testing.allocator);
//     defer expected.deinit();
//     try expected.append(.{ .number = 1 });
//     try expected.append(.{ .number = 2 });
//     try expected.append(.{ .number = 3 });
//
//     try program.execute();
//
//     try std.testing.expectEqual(expected, program.environment.get("x").?.array);
// }

// test "global and local scope environments do not collide" {
//     const src =
//         \\ {
//         \\   let x = 5;
//         \\ }
//     ;
//
//     var program = try mylang.createInterpreter(std.testing.allocator, src);
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//
//     try program.execute();
//
//     try std.testing.expect(!program.environment.contains("x"));
// }

test "evaluate object" {
    const src =
        \\ let x = {
        \\   a = 1,
        \\   b = 2,
        \\   c = 3
        \\ };
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }

    try program.execute();
    try std.testing.expect(program.environment.get("x").? == .object);
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

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }

    try program.execute();
    try std.testing.expectEqual(1.0, program.environment.get("x").?.number);
}

test "evaluate while loop" {
    const src =
        \\ let x = 0;
        \\
        \\ while x < 5 {
        \\   x = x + 1;
        \\ }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer {
        program.deinit();
        std.testing.allocator.destroy(program);
    }

    try program.execute();
    try std.testing.expectEqual(5.0, program.environment.get("x").?.number);
}
