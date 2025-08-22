const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const minhook = b.dependency("minhook", .{
        .target = target,
        .optimize = optimize,
    });

    //const stb = b.dependency("stb", .{
        //.target = target,
        //.optimize = optimize,
    //});

    const fat = b.dependency("fat", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/libmain.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "overlap",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    //lib.addIncludePath(stb.path(""));
    //lib.addCSourceFile(.{ .file = b.path("src/stb.c") });

    lib.root_module.addImport("fat", fat.module("fat"));

    switch (target.result.os.tag) {
        .windows => {
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
        },
        else => {},
    }

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
