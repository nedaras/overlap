const std = @import("std");
const d3dcommon = @import("d3dcommon.zig");
const windows = std.os.windows;

const UINT = windows.UINT;
const WINAPI = windows.WINAPI;
const SIZE_T = windows.SIZE_T;
const LPCSTR = windows.LPCSTR;
const HRESULT = windows.HRESULT;
const LPCVOID = windows.LPCVOID;
const ID3DBlob = d3dcommon.ID3DBlob;

pub const ID3DInclude = *opaque{};

pub const D3D_SHADER_MACRO = extern struct {
    Name: LPCSTR,
    Definition: LPCSTR,
};

pub extern "d3dcompiler_47" fn D3DCompile(
  pSrcData: LPCVOID,
  SrcDataSize: SIZE_T,
  pSourceName: ?LPCSTR,
  pDefines: ?*D3D_SHADER_MACRO,
  pInclude: ?*ID3DInclude,
  pEntrypoint: LPCSTR,
  pTarget: LPCSTR,
  Flags1: UINT,
  Flags2: UINT,
  ppCode: **ID3DBlob,
  ppErrorMsgs: ?**ID3DBlob,
) callconv(WINAPI) HRESULT;
