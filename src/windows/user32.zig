const windows = @import("../windows.zig");

const HWND = windows.HWND;
const BOOL = windows.BOOL;
const UINT = windows.UINT;
const WPARAM = windows.WPARAM;
const LPARAM = windows.LPARAM;
const WINAPI = windows.WINAPI;
const LPRECT = *windows.RECT;
const LPCSTR = windows.LPCSTR;
const WNDPROC = windows.WNDPROC;
const LRESULT = windows.LRESULT;
const LONG_PTR = windows.LONG_PTR;

pub extern "user32" fn GetForegroundWindow() callconv(WINAPI) ?HWND;

pub extern "user32" fn FindWindowA(lpClassName: ?LPCSTR, lpWindowName: ?LPCSTR) callconv(WINAPI) ?HWND;

pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: LPRECT) callconv(WINAPI) BOOL;

// todo: on 32bit use SetWindowLong
pub extern "user32" fn SetWindowLongPtrA(
    hWnd: HWND,
    nIndex: c_int,
    dwNewLong: LONG_PTR,
) callconv(WINAPI) LONG_PTR;

pub extern "user32" fn CallWindowProcA(
    lpPrevWndFunc: WNDPROC,
    hWnd: HWND,
    Msg: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(WINAPI) LRESULT;
