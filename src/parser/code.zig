const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

pub fn is(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return std.mem.startsWith(u8, trimmed, "```");
}

pub fn parse(
    arena: Allocator,
    reader: *Io.Reader,
    line: []const u8,
) error{ ReadFailed, StreamTooLong, OutOfMemory }!*Node {
    var lines: std.ArrayList([]const u8) = .empty;

    // TODO: Handle long lines
    while (try reader.takeDelimiter('\n')) |l| {
        if (std.mem.eql(u8, utils.trim(l), "```")) {
            break;
        }
        try lines.append(arena, l);
        try lines.append(arena, "\n");
    }
    var value = try std.mem.concat(arena, u8, lines.items);
    value = try std.mem.replaceOwned(u8, arena, value, "&", "&amp;");
    value = try std.mem.replaceOwned(u8, arena, value, "<", "&lt;");

    const node: *Node = try .create(arena, Ast.Code{ .value = value });

    if (line.len > 3) {
        node.code.lang = try arena.dupe(u8, line[3..]);
    }

    return node;
}
