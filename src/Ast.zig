const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const invariant = std.debug.assert;

pub const Ast = @This();

root: *Root,

pub const BuildError = Io.Reader.LimitedAllocError;

pub fn build(r: *Io.Reader, gpa: Allocator) BuildError!Ast {
    const root = try Node.create(gpa, Root, .{});

    const paragraph = try Node.create(gpa, Paragraph, .{});
    try root.append(gpa, paragraph);

    const value = try r.allocRemaining(gpa, .limited64(1024));
    std.mem.replaceScalar(u8, value, '\n', ' ');

    const text = try Node.create(gpa, Text, .{});
    text.set(value);
    try paragraph.append(gpa, text);

    return .{ .root = root.to(Root) };
}

pub fn deinit(self: *Ast, gpa: Allocator) void {
    Node.from(self.root).destroy(gpa);
}

pub const Kind = enum {
    blockquote,
    @"break",
    code,
    emphasis,
    heading,
    //  image,
    //  inline_code,
    //  link,
    //  list,
    //  list_item,
    paragraph,
    root,
    //  strong,
    text,

    const Group = enum {
        literal,
        parent,
    };

    pub fn from(comptime T: type) Kind {
        return switch (T) {
            Blockquote => .blockquote,
            Break => .@"break",
            Code => .code,
            Emphasis => .emphasis,
            Heading => .heading,
            Paragraph => .paragraph,
            Root => .root,
            Text => .text,
            else => @compileError("Invalid kind, got " ++ @typeName(T)),
        };
    }

    pub fn Type(self: Kind) type {
        return switch (self) {
            .blockquote => Blockquote,
            .@"break" => Break,
            .code => Code,
            .emphasis => Emphasis,
            .heading => Heading,
            .paragraph => Paragraph,
            .root => Root,
            .text => Text,
        };
    }

    pub fn is(self: Kind, grp: Group) bool {
        return self.group() == grp;
    }

    pub fn group(self: Kind) ?Group {
        return switch (self) {
            .blockquote,
            .emphasis,
            .heading,
            .paragraph,
            .root,
            => .parent,
            .code,
            .text,
            => .literal,
            .@"break",
            => null,
        };
    }
};

pub const Node = struct {
    kind: Kind,

    pub fn init(comptime T: type, values: anytype) T {
        Node.assert(T, Node);

        const V = @TypeOf(values);
        if (@typeInfo(V) != .@"struct") {
            @compileError("Expected values to be struct, got " ++ @typeName(V));
        }

        inline for (@typeInfo(V).@"struct".fields) |field| {
            if (!@hasField(T, field.name)) {
                @compileError("Invalid field in values: " ++ field.name);
            }
        }

        var node: T = undefined;
        const base: Node = .{
            .kind = Kind.from(T),
        };

        const Base = @FieldType(T, "base");
        @field(node, "base") = if (Base == Node) base else .init(base);

        inline for (@typeInfo(T).@"struct".fields) |field| {
            if (@hasField(V, field.name)) {
                @field(node, field.name) = @field(values, field.name);
            } else if (comptime field.defaultValue()) |default| {
                @field(node, field.name) = default;
            } else if (comptime !std.mem.eql(u8, "base", field.name)) {
                @compileError("Missing field: " ++ field.name);
            }
        }

        return node;
    }

    pub fn destroy(self: *Node, gpa: Allocator) void {
        switch (self.kind) {
            inline else => |k| {
                const T = k.Type();
                const node = self.to(T);

                if (@FieldType(T, "base") != Node) {
                    node.base.destroy(gpa);
                }

                gpa.destroy(node);
            },
        }
    }

    pub fn create(gpa: Allocator, T: type, values: anytype) Allocator.Error!*Node {
        const node = try gpa.create(T);
        node.* = Node.init(T, values);
        return Node.from(node);
    }

    pub fn set(self: *Node, value: []const u8) void {
        invariant(self.kind.is(.literal));
        const literal = self.to(Literal);
        literal.value = value;
    }

    pub fn append(self: *Node, gpa: Allocator, node: *Node) Allocator.Error!void {
        invariant(self.kind.is(.parent));
        const parent = self.to(Parent);
        try parent.children.append(gpa, node);
    }

    pub fn to(self: *Node, T: type) *T {
        Node.assert(T, Node);

        if (T == Node) {
            return self;
        }

        const Base = @FieldType(T, "base");
        return @alignCast(@fieldParentPtr("base", self.to(Base)));
    }

    pub fn from(node: anytype) *Node {
        const T = @TypeOf(node);
        const info = @typeInfo(T);
        if (info != .pointer or info.pointer.size != .one) {
            @compileError("Node single-item pointer, got " ++ @typeName(T));
        }

        const Child = info.pointer.child;
        if (Child == Node) {
            return node;
        } else if (@hasField(Child, "base")) {
            return from(&node.base);
        } else {
            @compileError("No base in " ++ @typeName(T));
        }
    }

    fn is(Unknown: type, T: type) bool {
        if (@typeInfo(Unknown) != .@"struct") {
            return false;
        }

        if (Unknown == T) {
            return true;
        }

        if (@hasField(Unknown, "base")) {
            return is(@FieldType(Unknown, "base"), T);
        }

        return false;
    }

    fn assert(comptime Unknown: type, comptime T: type) void {
        if (comptime !is(Unknown, T)) {
            const t_name = @typeName(T);
            const u_name = @typeName(Unknown);
            @compileError("Expected " ++ t_name ++ ", got " ++ u_name);
        }
    }
};

pub const Literal = struct {
    base: Node,
    value: []const u8,

    pub fn init(base: Node) Literal {
        return .{ .base = base, .value = &.{} };
    }

    pub fn destroy(self: *Literal, gpa: Allocator) void {
        gpa.free(self.value);
    }
};

pub const Parent = struct {
    base: Node,
    children: std.ArrayList(*Node),

    pub fn init(base: Node) Parent {
        return .{ .base = base, .children = .empty };
    }

    pub fn destroy(self: *Parent, gpa: Allocator) void {
        for (self.children.items) |child| {
            child.destroy(gpa);
        }
        self.children.deinit(gpa);
    }
};

pub const Blockquote = struct {
    base: Parent,
};

pub const Break = struct {
    base: Node,
};

pub const Code = struct {
    base: Literal,
    lang: ?[]const u8 = null,
    meta: ?[]const u8 = null,
};

pub const Emphasis = struct {
    base: Parent,
};

pub const Heading = struct {
    base: Parent,
};

pub const Html = struct {
    base: Literal,
};

pub const InlineCode = struct {
    base: Literal,
};

pub const List = struct {
    base: Parent,
    ordered: bool = false,
    start: ?u32 = null,
};

pub const ListItem = struct {
    base: Parent,
};

pub const Paragraph = struct {
    base: Parent,
};

pub const Root = struct {
    base: Parent,
};

pub const Strong = struct {
    base: Parent,
};

pub const Text = struct {
    base: Literal,
};

test "is Node" {
    try std.testing.expect(Node.is(Node, Node));
    try std.testing.expect(Node.is(Literal, Node));
    try std.testing.expect(Node.is(Parent, Node));
    try std.testing.expect(Node.is(Root, Node));
    try std.testing.expect(!Node.is(Kind, Node));
}

test "is Literal" {
    try std.testing.expect(Node.is(Literal, Literal));
    try std.testing.expect(!Node.is(Root, Literal));
    try std.testing.expect(!Node.is(Node, Literal));
    try std.testing.expect(!Node.is(Parent, Literal));
    try std.testing.expect(!Node.is(Kind, Literal));
}

test "is Parent" {
    try std.testing.expect(Node.is(Root, Parent));
    try std.testing.expect(Node.is(Parent, Parent));
    try std.testing.expect(!Node.is(Literal, Parent));
    try std.testing.expect(!Node.is(Node, Parent));
    try std.testing.expect(!Node.is(Kind, Parent));
}

test "it can parse a paragraph" {
    const gpa = std.testing.allocator;
    const buf = try gpa.alloc(u8, 1024);
    defer gpa.free(buf);

    const input =
        \\This is my new paragraph
        \\I have written in markdown
    ;
    const expected = "This is my new paragraph I have written in markdown";

    var reader = Io.Reader.fixed(input);

    var ast = try Ast.build(&reader, gpa);
    defer ast.deinit(gpa);

    try std.testing.expectEqual(ast.root.base.base.kind, .root);

    const paragraph = ast.root.base.children.items[0].to(Paragraph);
    const text = paragraph.base.children.items[0].to(Text);
    try std.testing.expectEqualStrings(expected, text.base.value);
}
