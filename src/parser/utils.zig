const std = @import("std");

pub fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, &std.ascii.whitespace);
}

pub const DelimiterError = error{
    ReadFailed,
    StreamTooLong,
};

pub fn peekLine(r: *std.Io.Reader) DelimiterError!?[]u8 {
    const inclusive = r.peekDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => {
            const remaining = r.buffer[r.seek..r.end];
            if (remaining.len == 0) return null;
            return remaining;
        },
        else => |e| return e,
    };
    return inclusive[0 .. inclusive.len - 1];
}
