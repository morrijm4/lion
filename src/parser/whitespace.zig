const std = @import("std");
const Io = std.Io;

pub fn skip(reader: *Io.Reader) Io.Reader.Error!void {
    while (std.ascii.isWhitespace(try reader.takeByte())) {}
}
