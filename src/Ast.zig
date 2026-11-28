const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Type = @import("Type.zig").Type;
const parser_utils = @import("parser/utils.zig");

pub const Ast = @This();

arena: std.heap.ArenaAllocator,
root: *Node,

pub const BuildError = Allocator.Error || Io.Reader.DelimiterError;

pub fn deinit(self: Ast) void {
    self.arena.deinit();
}

pub fn build(reader: *Io.Reader, gpa: Allocator) BuildError!Ast {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    var root: Root = .{};

    const parsers = .{
        @import("parser/code.zig"),
        @import("parser/list.zig"),
        @import("parser/heading.zig"),
        @import("parser/blockquote.zig"),
        @import("parser/paragraph.zig"),
    };

    const MAX_LINES = 1024 * 1024;

    // TODO: Handle lines longer than internal buffer
    var i: u32 = 0;
    while (try parser_utils.peekLine(reader)) |line| : (i += 1) {
        if (i >= MAX_LINES) {
            std.log.err("Max lines reached", .{});
            break;
        }

        // std.debug.print("{s}", .{line});
        if (parser_utils.trim(line).len == 0) {
            reader.toss(line.len);
            continue;
        }

        const node: *Node = blk: {
            inline for (parsers) |parser| {
                if (parser.valid(line)) break :blk try parser.parse(a, reader);
            }

            reader.toss(line.len);

            std.log.warn("Unsupported: {s}", .{line});
            break :blk try .create(a, Text{ .value = try a.dupe(u8, line) });
        };

        try root.children.append(a, node);
    }

    const node: *Node = try .create(a, root);
    return .{
        .arena = arena,
        .root = node,
    };
}

fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, &std.ascii.whitespace);
}

pub const Node = union(Type) {
    blockquote: Blockquote,
    @"break": Break,
    code: Code,
    emphasis: Emphasis,
    heading: Heading,
    html: Html,
    //  image,
    inline_code: InlineCode,
    //  link,
    list: List,
    list_item: ListItem,
    paragraph: Paragraph,
    root: Root,
    strong: Strong,
    text: Text,

    pub fn create(arena: Allocator, data: anytype) Allocator.Error!*Node {
        inline for (@typeInfo(Node).@"union".fields) |f| {
            if (f.type == @TypeOf(data)) {
                const node = try arena.create(Node);
                node.* = @unionInit(Node, f.name, data);
                return node;
            }
        }
        @compileError("Expected node type, got " ++ @typeName(@TypeOf(data)));
    }

    pub fn children(self: *Node) ?*std.ArrayList(*Node) {
        switch (self.*) {
            inline else => |*node| {
                if (@hasField(@TypeOf(node.*), "children")) {
                    return &node.children;
                } else {
                    return null;
                }
            },
        }
    }
};

pub const Blockquote = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Break = struct {};

pub const Code = struct {
    value: []const u8,
    lang: ?[]const u8 = null,
    meta: ?[]const u8 = null,
};

pub const Emphasis = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Heading = struct {
    children: std.ArrayList(*Node) = .empty,
    depth: u3,
};

pub const Html = struct {
    value: []const u8,
};

pub const InlineCode = struct {
    value: []const u8,
};

pub const List = struct {
    children: std.ArrayList(*Node) = .empty,
    ordered: bool = false,
    start: ?u32 = null,
};

pub const ListItem = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Paragraph = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Root = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Strong = struct {
    children: std.ArrayList(*Node) = .empty,
};

pub const Text = struct {
    value: []const u8,
};

test "it can parse a paragraph" {
    const gpa = std.testing.allocator;
    const input =
        \\This is my new paragraph
        \\I have written in markdown
    ;
    const e0 = "This is my new paragraph";
    const e1 = "I have written in markdown";

    var reader = Io.Reader.fixed(input);

    var ast = try Ast.build(&reader, gpa);
    defer ast.deinit();

    const node = ast.root.children().?.items[0];
    const t0 = node.children().?.items[0];
    const t1 = node.children().?.items[1];

    try std.testing.expect(node.* == .paragraph);
    try std.testing.expect(t0.* == .text);
    try std.testing.expect(t1.* == .text);
    try std.testing.expectEqualStrings(e0, t0.text.value);
    try std.testing.expectEqualStrings(e1, t1.text.value);
}
