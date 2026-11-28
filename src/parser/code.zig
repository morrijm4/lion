const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

const DELIMITER = "```";

pub fn valid(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return std.mem.startsWith(u8, trimmed, DELIMITER);
}

const Error = Allocator.Error || error{ ReadFailed, StreamTooLong };

pub fn parse(arena: Allocator, reader: *Io.Reader) Error!*Node {
    const first_line = try reader.takeDelimiter('\n') orelse unreachable;
    assert(valid(first_line));

    var lines: std.ArrayList([]const u8) = .empty;

    // TODO: Handle long lines
    while (try reader.takeDelimiter('\n')) |line| {
        if (valid(line)) break;
        try lines.append(arena, line);
        try lines.append(arena, "\n");
    }

    var value = try std.mem.concat(arena, u8, lines.items);
    value = try std.mem.replaceOwned(u8, arena, value, "&", "&amp;");
    value = try std.mem.replaceOwned(u8, arena, value, "<", "&lt;");

    var code: Ast.Code = .{ .value = value };

    if (first_line.len > 3) {
        code.lang = try arena.dupe(u8, first_line[DELIMITER.len..]);
    }

    return try .create(arena, code);
}
