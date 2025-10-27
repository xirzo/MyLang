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
