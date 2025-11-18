const std = @import("std");
const windows = @import("../windows.zig");
const d3d11 = windows.d3d11;

pub fn hook(d3d11_lib: windows.HMODULE) void {
    const hwnd = try windows.CreateWindowEx(
        0,
        "STATIC",
        "Overlap DXGI Window",
        windows.WS_OVERLAPPEDWINDOW,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        640,
        480,
        null,
        null,
        null,
        null,
    );
    defer windows.DestroyWindow(hwnd);

    const D3D11CreateDeviceAndSwapChain = *const @TypeOf(d3d11.D3D11CreateDeviceAndSwapChain);
    const d3d11_create_device_and_swap_chain: D3D11CreateDeviceAndSwapChain = @ptrCast(try windows.GetProcAddress(
        d3d11_lib,
        "D3D11CreateDeviceAndSwapChain",
    ));

    const hr = d3d11_create_device_and_swap_chain(

    );
}
