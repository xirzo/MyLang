const std = @import("std");
const mylang = @import("mylang");

test "global and local scope environments do not collide" {
    const src =
        \\ {
        \\   let x = 5;
        \\ }
    ;

    var program = try mylang.createInterpreter(std.testing.allocator, src);
    defer std.testing.allocator.destroy(program);
    defer program.deinit();

    try program.execute();

    try std.testing.expect(!program.environment.contains("x"));
}
