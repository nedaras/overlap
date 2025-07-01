const windows = @import("../windows.zig");

const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
pub const HSTRING = *opaque{};
const REFID = windows.REFIID;
const PCNZWCH = windows.PCWSTR;
const UINT32 = u32;

pub extern "combase" fn RoGetActivationFactory(
    activatableClassId: HSTRING,
    iid: REFID,
    factory: **anyopaque,
) callconv(WINAPI) HRESULT;

pub extern "combase" fn WindowsCreateString(
    sourceString: PCNZWCH,
    length: UINT32,
    string: *HSTRING,
) callconv(WINAPI) HRESULT;
