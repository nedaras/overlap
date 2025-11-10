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

    const detours = b.dependency("detours", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/libmain2.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "overlap",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    lib.linkLibCpp();
    //lib.adIncludePath(stb.path(""));
    //lib.addCSourceFile(.{ .file = b.path("src/stb.c") });

    lib.root_module.addImport("fat", fat.module("fat"));

    lib.addIncludePath(detours.path("src"));

    //lib.root_module.addCMacro("WIN32_LEAN_AND_MEAN", "");
    //lib.root_module.addCMacro("_WIN32_WINNT", "0x501");

    lib.addCSourceFiles(.{
        .root = detours.path("src"),
        .files = &.{
            "creatwth.cpp",
            "detours.cpp",
            "disasm.cpp",
            "disolarm.cpp",
            "disolarm64.cpp",
            "disolia64.cpp",
            "disolx64.cpp",
            "disolx86.cpp",
            "image.cpp",
            "modules.cpp",
            // "uimports.cpp",
        },
    });

    switch (target.result.cpu.arch) {
        .x86 => {
            lib.root_module.addCMacro("DETOURS_X86", "1");
        },
        .x86_64 => {
            lib.root_module.addCMacro("DETOURS_X64", "1");
            lib.root_module.addCMacro("DETOURS_64BIT", "1");
        },
        .arm => {
            lib.root_module.addCMacro("DETOURS_ARM", "1");
        },
        .aarch64 => {
            lib.root_module.addCMacro("DETOURS_ARM64", "1");
            lib.root_module.addCMacro("DETOURS_64BIT", "1");
        },
        else => {
            std.debug.panic(
                "Unsupported CPU architecture: {}",
                .{target.result.cpu.arch},
            );
        },
    }

    lib.root_module.addCMacro("WIN32_LEAN_AND_MEAN", "");

    _ = minhook;
    switch (target.result.os.tag) {
        //.windows => {
            //lib.addIncludePath(minhook.path("src"));
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
        //},
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
