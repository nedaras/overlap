const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const minhook = b.dependency("minhook", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/dllmain.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addSharedLibrary(.{
        .name = "overlap",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    lib.addIncludePath(minhook.path("include"));

    lib.addCSourceFiles(.{
        .root = minhook.path("src"),
        .files = &.{
            "hook.c",
            "buffer.c",
            "hde/hde32.c",
            "hde/hde64.c",
            "trampoline.c",
        },
    });

    b.installArtifact(lib);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "overlap",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.addIncludePath(minhook.path("include"));

    exe.addCSourceFiles(.{
        .root = minhook.path("src"),
        .files = &.{
            "hook.c",
            "buffer.c",
            "hde/hde32.c",
            "hde/hde64.c",
            "trampoline.c",
        },
    });

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

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
