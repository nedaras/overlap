const std = @import("std");
const windows = std.os.windows;

// would be intresting to rewrite minhook in zig

const INT = windows.INT;
const LPVOID = windows.LPVOID;
const LPCVOID = windows.LPCVOID;

pub const MH_STATUS = enum(INT) {
    // Unknown error. Should not be returned.
    UNKNOWN = -1,
    // Successful.
    OK = 0,
    // MinHook is already initialized.
    ERROR_ALREADY_INITIALIZED = 1,
    // MinHook is not initialized yet, or already uninitialized.
    ERROR_NOT_INITIALIZED = 2,
    // The hook for the specified target function is already created.
    ERROR_ALREADY_CREATED = 3,
    // The hook for the specified target function is not created yet.
    ERROR_NOT_CREATED = 4,
    // The hook for the specified target function is already enabled.
    ERROR_ENABLED = 5,
    // The hook for the specified target function is not enabled yet, or already
    // disabled.
    ERROR_DISABLED = 6,
    // The specified pointer is invalid. It points the address of non-allocated
    // and/or non-executable region.
    ERROR_NOT_EXECUTABLE = 7,
    // The specified target function cannot be hooked.
    ERROR_UNSUPPORTED_FUNCTION = 8,
    // Failed to allocate memory.
    ERROR_MEMORY_ALLOC = 9,
    // Failed to change the memory protection.
    ERROR_MEMORY_PROTECT = 10,
    // The specified module is not loaded.
    ERROR_MODULE_NOT_FOUND = 11,
    // The specified function is not found.
    ERROR_FUNCTION_NOT_FOUND = 12,

    _,
};

pub extern fn MH_Initialize() callconv(.C) MH_STATUS;

pub extern fn MH_Uninitialize() callconv(.C) MH_STATUS;

pub extern fn MH_CreateHook(pTarget: LPCVOID, pDetour: LPCVOID, ppOriginal: *LPVOID) callconv(.C) MH_STATUS;

pub extern fn MH_EnableHook(pTarget: LPCVOID) callconv(.C) MH_STATUS;

pub extern fn MH_DisableHook(pTarget: LPCVOID) callconv(.C) MH_STATUS;

pub extern fn MH_RemoveHook(pTarget: LPCVOID) callconv(.C) MH_STATUS;
