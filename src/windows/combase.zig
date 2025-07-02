const windows = @import("../windows.zig");

const UINT32 = windows.UINT32;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const REFIID = windows.REFIID;
const PCNZWCH = windows.PCNZWCH;
const HSTRING = windows.HSTRING;
const RO_INIT_TYPE = windows.RO_INIT_TYPE;
const PCWSTR = windows.PCWSTR;

pub extern fn RoInitialize(initType: RO_INIT_TYPE) callconv(WINAPI) HRESULT;

pub extern fn RoUninitialize() void;

pub extern fn RoGetActivationFactory(
    activatableClassId: HSTRING,
    iid: REFIID,
    factory: **anyopaque,
) callconv(WINAPI) HRESULT;

pub extern fn WindowsCreateString(
    sourceString: PCNZWCH,
    length: UINT32,
    string: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern fn WindowsDeleteString(
    string: HSTRING,
) callconv(WINAPI) HRESULT;

pub extern fn WindowsGetStringRawBuffer(
    string: HSTRING,
    length: *UINT32,
) callconv(WINAPI) ?PCWSTR;
