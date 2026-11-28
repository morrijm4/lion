const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

const MAX_HEADING_DEPTH = 6;

pub fn valid(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return trimmed.len != 0 and trimmed[0] == '#';
}

const Error = Allocator.Error || error{ ReadFailed, StreamTooLong };

pub fn parse(arena: Allocator, reader: *Io.Reader) Error!*Node {
    const line = try reader.takeDelimiter('\n') orelse unreachable;

    var depth: u3 = 0;
    while (depth <= MAX_HEADING_DEPTH and depth < line.len) : (depth += 1) {
        if (line[depth] != '#') break;
    }

    assert(depth >= 1);
    assert(depth <= 6);

    var heading: Ast.Heading = .{ .depth = depth };

    try heading.children.append(arena, try .create(arena, Ast.Text{
        .value = try arena.dupe(u8, utils.trim(line[depth..])),
    }));

    return try .create(arena, heading);
}
