const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---CLI---
    const cli_module = b.createModule(.{
        .root_source_file = b.path("cli/cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    // circular
    cli_module.addImport("cli", cli_module);

    // ---FS---
    const efs_module = b.createModule(.{
        .root_source_file = b.path("src/efs/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // -----------------

    const exe = b.addExecutable(.{
        .name = "zigfs",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Dependecies
    exe.root_module.addImport("cli", cli_module);
    exe.root_module.addImport("efs", efs_module);

    b.installArtifact(exe);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
