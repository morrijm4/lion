const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

const Error = Allocator.Error || Io.Reader.DelimiterError;

pub fn valid(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return trimmed.len != 0 and trimmed[0] == '>';
}

pub fn parse(arena: Allocator, reader: *Io.Reader) Error!*Node {
    var blockquote: Ast.Blockquote = .{};

    while (try utils.peekLine(reader)) |line| {
        if (!valid(line)) {
            break;
        }

        reader.toss(line.len);

        try blockquote.children.append(arena, try .create(arena, Ast.Text{
            .value = try arena.dupe(u8, format(line)),
        }));
    }

    return try .create(arena, blockquote);
}

fn format(line: []const u8) []const u8 {
    assert(valid(line));
    return utils.trim(line[1..]);
}
