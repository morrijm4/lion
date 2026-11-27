const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

const MAX_HEADING_DEPTH = 6;

pub fn is(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return trimmed.len != 0 and trimmed[0] == '#';
}

pub fn parse(
    arena: Allocator,
    reader: *Io.Reader,
    line: []const u8,
) Allocator.Error!*Node {
    _ = reader;
    var depth: u3 = 0;
    while (depth <= MAX_HEADING_DEPTH and depth < line.len) : (depth += 1) {
        if (line[depth] != '#') break;
    }

    assert(depth >= 1);
    assert(depth <= 6);

    const heading: *Node = try .create(arena, Ast.Heading{ .depth = depth });
    const title = try arena.dupe(u8, utils.trim(line[depth..]));
    const text: *Node = try .create(arena, Ast.Text{ .value = title });
    try heading.children().?.append(arena, text);
    return heading;
}
