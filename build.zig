const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("bin/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) {
        lib_mod.strip = true;
        exe_mod.strip = true;
    }

    exe_mod.addImport("mylang", lib_mod);

    const lib = b.addLibrary(.{
        .name = "mylang",
        .root_module = lib_mod,
    });

    const exe = b.addExecutable(.{
        .name = "mylang",
        .root_module = exe_mod,
    });

    b.installArtifact(lib);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_files = [_][]const u8{
        "tests/environment_tests.zig",
        "tests/evaluator_tests.zig",
        "tests/function_tests.zig",
        "tests/lexer_tests.zig",
        "tests/parser_tests.zig",
        // "tests/integration_tests.zig",
    };

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    for (test_files) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });

        test_mod.addImport("mylang", lib_mod);

        const unit_test = b.addTest(.{
            .root_module = test_mod,
        });

        const run_unit_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_test.step);
    }
}
