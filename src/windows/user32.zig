const windows = @import("../windows.zig");

const HWND = windows.HWND;
const BOOL = windows.BOOL;
const UINT = windows.UINT;
const DWORD = windows.DWORD;
const WPARAM = windows.WPARAM;
const LPARAM = windows.LPARAM;
const LPRECT = *windows.RECT;
const LPCSTR = windows.LPCSTR;
const LPSTR = windows.LPSTR;
const HHOOK = windows.HHOOK;
const WNDPROC = windows.WNDPROC;
const LRESULT = windows.LRESULT;
const LONG_PTR = windows.LONG_PTR;
const LPDWORD = windows.LPDWORD;
const WNDENUMPROC = windows.WNDENUMPROC;

pub extern "user32" fn GetForegroundWindow() callconv(.winapi) ?HWND;

pub extern "user32" fn FindWindowA(lpClassName: ?LPCSTR, lpWindowName: ?LPCSTR) callconv(.winapi) ?HWND;

pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: LPRECT) callconv(.winapi) BOOL;

// todo: on 32bit use SetWindowLong
pub extern "user32" fn SetWindowLongPtrA(
    hWnd: HWND,
    nIndex: c_int,
    dwNewLong: LONG_PTR,
) callconv(.winapi) LONG_PTR;

pub extern "user32" fn CallWindowProcA(
    lpPrevWndFunc: WNDPROC,
    hWnd: HWND,
    Msg: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub extern "user32" fn FindWindowExA(
    hWndParent: ?HWND,
    hWndChildAfter: ?HWND,
    lpszClass: ?LPCSTR,
    lpszWindow: ?LPCSTR,
) callconv(.winapi) ?HWND;

pub extern "user32" fn GetWindowThreadProcessId(hWnd: HWND, lpdwProcessId: ?LPDWORD) callconv(.winapi) DWORD;

pub extern "user32" fn GetWindow(hWnd: HWND, uCmd: UINT) callconv(.winapi) ?HWND;

pub extern "user32" fn GetAncestor(hWnd: HWND, gaFlags: UINT) callconv(.winapi) ?HWND;

pub extern "user32" fn GetClassNameA(
    hWnd: HWND,
    lpClassName: [*]u8,
    nMaxCount: c_int,
) callconv(.winapi) c_int;

pub extern "user32" fn EnumWindows(
    lpEnumFunc: WNDENUMPROC,
    lParam: LPARAM,
) callconv(.winapi) BOOL;

pub extern "user32" fn CallNextHookEx(
    hhk: ?HHOOK,
    nCode: c_int,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;
