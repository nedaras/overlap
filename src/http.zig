const WinHttpClient = @import("http/WinHttpClient.zig");

// we later will have CurlClient
// and we should use smth like Impl and normalize errors
pub const Client = WinHttpClient;
