const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Ast = @This();

arena: std.heap.ArenaAllocator,
root: *Node,

pub const BuildError = Io.Reader.LimitedAllocError;

pub fn build(r: *Io.Reader, gpa: Allocator) BuildError!Ast {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    const root: *Node = try .create(a, Root{});

    const paragraph: *Node = try .create(a, Paragraph{});
    try root.children().?.append(a, paragraph);

    const value = try r.allocRemaining(a, .limited64(1024 * 1024));
    std.mem.replaceScalar(u8, value, '\n', ' ');

    const text: *Node = try .create(a, Text{ .value = value });
    try paragraph.children().?.append(a, text);

    return .{ .arena = arena, .root = root };
}

pub fn deinit(self: *Ast) void {
    self.arena.deinit();
}

pub const Node = union(enum) {
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
    const expected = "This is my new paragraph I have written in markdown";

    var reader = Io.Reader.fixed(input);

    var ast = try Ast.build(&reader, gpa);
    defer ast.deinit();

    const paragraph = ast.root.children().?.items[0];
    const text = paragraph.children().?.items[0];

    try std.testing.expect(paragraph.* == .paragraph);
    try std.testing.expect(text.* == .text);
    try std.testing.expectEqualStrings(expected, text.text.value);
}
