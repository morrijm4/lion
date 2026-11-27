const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const utils = @import("utils.zig");
const Ast = @import("../Ast.zig");
const Node = Ast.Node;

const Error = Allocator.Error || utils.DelimiterError;

pub fn is(line: []const u8) bool {
    const trimmed = utils.trim(line);
    return trimmed.len != 0 and trimmed[0] == '-';
}

pub fn parse(arena: Allocator, reader: *Io.Reader, line: []const u8) Error!*Node {
    var list: Ast.List = .{};

    var li: Ast.ListItem = .{};
    try li.children.append(arena, try .create(arena, Ast.Text{
        .value = try arena.dupe(u8, format(line)),
    }));
    try list.children.append(arena, try .create(arena, li));

    while (try utils.peekLine(reader)) |next| {
        if (!is(next)) {
            break;
        }

        reader.toss(next.len);

        var item: Ast.ListItem = .{};
        try item.children.append(arena, try .create(arena, Ast.Text{
            .value = try arena.dupe(u8, format(line)),
        }));
        try list.children.append(arena, try .create(arena, item));
    }

    return try .create(arena, list);
}

fn format(item: []const u8) []const u8 {
    assert(is(item));
    return utils.trim(item[1..]);
}
