const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for our source code
    const browser_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "zig-browser",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Example executable
    const example = b.addExecutable(.{
        .name = "parser-example",
        .root_source_file = .{ .cwd_relative = "examples/simple.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the module to the example
    example.root_module.addImport("browser", browser_module);

    b.installArtifact(example);

    // Run command for main executable
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the browser");
    run_step.dependOn(&run_cmd.step);

    // Run command for example
    const run_example = b.addRunArtifact(example);
    const run_example_step = b.step("run-example", "Run the parser example");
    run_example_step.dependOn(&run_example.step);

    // Tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_main_tests.step);
}
