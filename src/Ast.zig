const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Type = @import("Type.zig").Type;

pub const Ast = @This();

arena: std.heap.ArenaAllocator,
root: *Node,

const MAX_HEADING_DEPTH = 6;

pub const BuildError = Allocator.Error || error{
    ReadFailed,
    StreamTooLong,
    Invalid,
    Unsupported,
};

pub fn deinit(self: Ast) void {
    self.arena.deinit();
}

pub fn build(reader: *Io.Reader, gpa: Allocator) BuildError!Ast {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    const root: *Node = try .create(a, Root{});
    const children = root.children().?;

    while (try reader.takeDelimiter('\n')) |line| {
        if (line.len == 0) {
            try children.append(a, try .create(a, Paragraph{}));
        } else if (line[0] == '#') {
            try children.append(a, try buildHeading(a, line));
        } else if (std.ascii.isAlphabetic(line[0])) {
            const maybe_last = children.getLastOrNull();
            if (maybe_last == null or maybe_last.?.* != .paragraph) {
                try children.append(a, try .create(a, Paragraph{}));
            }

            const last = children.getLast();
            const text: *Node = try .create(a, Text{ .value = trim(line) });
            try last.children().?.append(a, text);
        } else {
            return error.Unsupported;
        }
    }

    return .{ .arena = arena, .root = root };
}

const BuildHeadingError = Allocator.Error || error{Invalid};

pub fn buildHeading(arena: Allocator, line: []const u8) BuildHeadingError!*Node {
    var depth: u3 = 0;
    while (depth <= MAX_HEADING_DEPTH and depth < line.len) : (depth += 1) {
        if (line[depth] != '#') break;
    }

    assert(depth >= 1);
    assert(depth <= 6);

    const heading: *Node = try .create(arena, Heading{ .depth = depth });
    const title = try arena.dupe(u8, trim(line[depth..]));
    try heading.children().?.append(arena, try .create(arena, Text{ .value = title }));
    return heading;
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

    const paragraph = ast.root.children().?.items[0];
    const t0 = paragraph.children().?.items[0];
    const t1 = paragraph.children().?.items[1];

    try std.testing.expect(paragraph.* == .paragraph);
    try std.testing.expect(t0.* == .text);
    try std.testing.expect(t1.* == .text);
    try std.testing.expectEqualStrings(e0, t0.text.value);
    try std.testing.expectEqualStrings(e1, t1.text.value);
}
