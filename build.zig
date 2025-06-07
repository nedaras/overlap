const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const minhook = b.dependency("minhook", .{
        //.target = target,
        //.optimize = optimize,
    //});

    const zigzag = b.dependency("zigzag", .{
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

    lib_mod.addImport("zigzag", zigzag.module("zigzag"));

    //lib.linkLibC();
    //lib.addIncludePath(minhook.path("include"));

    //lib.addCSourceFiles(.{
        //.root = minhook.path("src"),
        //.files = &.{
            //"hook.c",
            //"buffer.c",
            //"hde/hde32.c",
            //"hde/hde64.c",
            //"trampoline.c",
        //},
    //});

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
