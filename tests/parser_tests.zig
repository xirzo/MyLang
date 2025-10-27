const std = @import("std");
const mylang = @import("mylang");

// test "assign number to a variable" {
//     const src = "let x = 5;";
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(lexer, std.testing.allocator);
//
//     var program = try parser.parse();
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//
//     try program.execute();
//
//     const value = program.environment.get("x") orelse {
//         std.log.debug("Variable 'x' not found in environment\n", .{});
//         return error.TestExpectedEqual;
//     };
//
//     try std.testing.expect(value.number == 5.0);
// }
//
// test "assign vartiable value to a variable" {
//     const src =
//         \\let x = 5;
//         \\let y = x + 1;
//     ;
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(lexer, std.testing.allocator);
//
//     var program = try parser.parse();
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//
//     try program.execute();
//
//     const value = program.environment.get("y") orelse {
//         std.log.debug("Variable 'y' not found in environment\n", .{});
//         return error.TestExpectedEqual;
//     };
//
//     try std.testing.expect(value.number == 6.0);
// }
//
// test "assign block to a variable" {
//     const src =
//         \\let x = {
//         \\
//         \\};
//     ;
//     const lexer = mylang.Lexer.init(src);
//     var parser = mylang.Parser.init(lexer, std.testing.allocator);
//
//     var program = try parser.parse();
//     defer std.testing.allocator.destroy(program);
//     defer program.deinit();
//
//     try program.execute();
//
//     const value = program.environment.get("y") orelse {
//         std.log.debug("Variable 'y' not found in environment\n", .{});
//         return error.TestExpectedEqual;
//     };
//
//     try std.testing.expect(value.number == 6.0);
// }
