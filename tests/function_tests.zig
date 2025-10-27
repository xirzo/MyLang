const std = @import("std");
const mylang = @import("mylang");

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

test "declare a function with return statement" {
    const src =
        \\ fn test() {
        \\   ret 5;
        \\ }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    try std.testing.expect(program.getFunction("test") != null);
}

test "call a function with value" {
    const src =
        \\ fn test() {
        \\   ret 5;
        \\ }
        \\ let x = test();
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const value = program.environment.get("x") orelse {
        std.log.debug("Variable 'x' not found in environment\n", .{});
        return error.TestExpectedEqual;
    };

    try std.testing.expectEqual(value.number, 5.0);
}

test "double ret function" {
    const src =
        \\ fn test(x) {
        \\ if x < 0 {
        \\   ret 0;
        \\ }
        \\   ret 1;
        \\ }
        \\ let x = test(2);
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const value = program.environment.get("x") orelse {
        std.log.debug("Variable 'x' not found in environment\n", .{});
        return error.TestExpectedEqual;
    };

    try std.testing.expectEqual(value.number, 1.0);
}

test "count fibonacci sequence" {
    const src =
        \\ fn fib(n) {
        \\     if n <= 1 {
        \\         ret n;
        \\     }
        \\
        \\     ret fib(n-1) + fib(n-2);
        \\ }
        \\
        \\ let x = fib(5);
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    const value = program.environment.get("x") orelse {
        std.log.debug("Variable 'x' not found in environment\n", .{});
        return error.TestExpectedEqual;
    };

    try std.testing.expectEqual(value.number, 5.0);
}
