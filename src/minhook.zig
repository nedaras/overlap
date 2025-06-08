const std = @import("std");
const minhook = @import("minhook/minhook.zig");

pub const MH_InitializeError = error{Unexpected};

pub fn MH_Initialize() MH_InitializeError!void {
    return switch (minhook.MH_Initialize()) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const MH_UninitializeError = error{Unexpected};

pub fn MH_Uninitialize() MH_UninitializeError!void {
    return switch (minhook.MH_Uninitialize()) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const MH_CreateHookError = error{Unexpected};

pub fn MH_CreateHook(comptime T: type, pTarget: *const T, pDetour: *const T, ppOriginal: **T) MH_CreateHookError!void {
    // todo: FIX
    // found like a bug on Debug/Safe modes where there is runtime safety
    // if a function is already hooked by bo some other process zig catches that there is bad alignment in hde64.c
    // hs->imm.imm32 = *(uint32_t*)p;
    // and this line makes zig panic
    // though on Unsafe mods like Fast/Small it does not seem to cauz any problems
    // so we can `@setRuntimeSafety(false);` to ignore it, but idk mb this is a bug in minhook
    return switch (minhook.MH_CreateHook(pTarget, pDetour, ppOriginal)) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const MH_EnableHookError = error{Unexpected};

pub fn MH_EnableHook(comptime T: type, pTarget: *const T) MH_EnableHookError!void {
    return switch (minhook.MH_EnableHook(pTarget)) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const MH_DisableHookError = error{Unexpected};

pub fn MH_DisableHook(comptime T: type, pTarget: *const T) MH_DisableHookError!void {
    return switch (minhook.MH_DisableHook(pTarget)) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const MH_RemoveHookError = error{Unexpected};

pub fn MH_RemoveHook(comptime T: type, pTarget: *const T) MH_RemoveHookError!void {
    return switch (minhook.MH_RemoveHook(pTarget)) {
        .OK => {},
        else => |err| unexpectedError(err),
    };
}

pub const UnexpectedError = error{
    Unexpected,
};

pub fn unexpectedError(mh_status: minhook.MH_STATUS) UnexpectedError {
    if (std.posix.unexpected_error_tracing) {
        const tag_name = std.enums.tagName(minhook.MH_STATUS, mh_status) orelse "";
        std.debug.print("error.Unexpected: MH_STATUS({d}): {s}\n", .{
            @intFromEnum(mh_status),
            tag_name,
        });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}
