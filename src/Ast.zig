const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
const assert = std.debug.assert;

pub const Ast = @This();

root: Root,

pub const BuildError = Io.Reader.LimitedAllocError;

pub fn build(r: *Io.Reader, fba: *FixedBufferAllocator) BuildError!Ast {
    const gpa = fba.allocator();

    var ast: Ast = .{
        .root = .init(),
    };

    const paragraph = try Parent.create(gpa, Paragraph);
    try ast.root.base.append(gpa, .from(paragraph));

    const value = try r.allocRemaining(gpa, .limited64(1024));
    std.mem.replaceScalar(u8, value, '\n', ' ');

    const text = try Literal.create(gpa, Text, value);
    try paragraph.base.append(gpa, .from(text));

    return ast;
}

pub const Type = enum {
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
};

pub const Node = union(Type) {
    blockquote,
    @"break",
    code: struct { lang: ?[]const u8, meta: ?[]const u8 },
    emphasis,
    heading: struct { depth: u3 },
    paragraph,
    root,
    text,

    pub fn from(ptr: anytype) *const Node {
        const T = @TypeOf(ptr);
        const info = @typeInfo(T);
        if (info != .pointer or info.pointer.size != .one)
            @compileError("from() needs a pointer, got " ++ @typeName(T));

        const Child = info.pointer.child;
        if (Child == Node) {
            return ptr;
        } else if (@hasField(Child, "node")) {
            return from(&ptr.node);
        } else if (@hasField(Child, "base")) {
            return from(&ptr.base);
        } else {
            @compileError("Expected Node type, got " ++ @typeName(T));
        }
    }

    pub fn isLiteral(self: Node) bool {
        return switch (self) {
            // Literals
            .code,
            .text,
            => true,

            // Parents
            .blockquote,
            .emphasis,
            .heading,
            .paragraph,
            .root,
            => false,

            // Nodes
            .@"break",
            => false,
        };
    }

    pub fn isParent(self: Node) bool {
        return switch (self) {
            // Literals
            .code,
            .text,
            => false,

            // Parents
            .blockquote,
            .emphasis,
            .heading,
            .paragraph,
            .root,
            => true,

            // Nodes
            .@"break",
            => false,
        };
    }

    pub fn asLiteral(self: *const Node) *const Literal {
        assert(self.isLiteral());
        return @fieldParentPtr("node", self);
    }

    pub fn asParent(self: *const Node) *const Parent {
        assert(self.isParent());
        return @fieldParentPtr("node", self);
    }

    pub fn asParagraph(self: *const Node) *const Paragraph {
        assert(self.* == .paragraph);
        const base = self.asParent();
        return @fieldParentPtr("base", base);
    }

    pub fn asRoot(self: *const Node) *const Root {
        assert(self.* == .root);
        const base = self.asParent();
        return @fieldParentPtr("base", base);
    }

    pub fn asText(self: *const Node) *const Text {
        assert(self.* == .text);
        const base = self.asLiteral();
        return @fieldParentPtr("base", base);
    }
};

pub const Literal = struct {
    node: Node,
    value: []const u8,

    pub fn init(node: Node, value: []const u8) Literal {
        return .{
            .node = node,
            .value = value,
        };
    }

    pub fn create(gpa: Allocator, T: type, value: []const u8) Allocator.Error!*T {
        if (!@hasDecl(T, "init"))
            @compileError("Expected type with init declaration, got " ++ @typeName(T));

        const Decl = @TypeOf(@field(T, "init"));
        const info = @typeInfo(Decl);
        if (info != .@"fn")
            @compileError("Expected init to be a function, got " ++ @typeName(Decl));

        const params = info.@"fn".params;
        if (params.len != 1)
            @compileError("Expected init to accept 1 parameter, got " ++ params.len);

        if (params[0].type != []const u8)
            @compileError("Expected init to accept []const u8, got " ++ @typeName(params[0].type));

        const n = try gpa.create(T);
        n.* = T.init(value);
        return n;
    }
};

pub const Parent = struct {
    node: Node,
    children: std.ArrayList(*const Node),

    pub fn init(node: Node) Parent {
        return .{
            .node = node,
            .children = .empty,
        };
    }

    pub fn create(gpa: Allocator, T: type) Allocator.Error!*T {
        if (!@hasDecl(T, "init"))
            @compileError("Expected type with init declaration, got " ++ @typeName(T));

        const n = try gpa.create(T);
        n.* = T.init();
        return n;
    }

    pub fn append(self: *Parent, gpa: Allocator, node: *const Node) Allocator.Error!void {
        try self.children.append(gpa, node);
    }
};

pub const Paragraph = struct {
    base: Parent,

    pub fn init() Paragraph {
        return .{
            .base = .init(.{ .paragraph = {} }),
        };
    }
};

pub const Root = struct {
    base: Parent,

    pub fn init() Root {
        return .{
            .base = .init(.{ .root = {} }),
        };
    }
};

pub const Text = struct {
    base: Literal,

    pub fn init(value: []const u8) Text {
        return .{
            .base = .init(.{ .text = {} }, value),
        };
    }
};

test "paragraph can cast into a node and back" {
    const paragraph = Paragraph.init();
    const node = Node.from(&paragraph);
    try std.testing.expectEqual(.paragraph, node.*);
    const p = node.asParagraph();
    try std.testing.expectEqual(.paragraph, p.base.node);
}

test "text can cast into a node and back" {
    const text = Text.init("hi, mom!");
    const node = Node.from(&text);
    try std.testing.expectEqual(.text, node.*);
    const t = node.asText();
    try std.testing.expectEqualStrings("hi, mom!", t.base.value);
}

test "root can cast into a node and back" {
    const root = Root.init();
    const node = Node.from(&root);
    try std.testing.expectEqual(.root, node.*);
    const r = node.asRoot();
    try std.testing.expectEqual(.root, r.base.node);
}

test "it can parse a paragraph" {
    const gpa = std.testing.allocator;
    var fba = FixedBufferAllocator.init(try gpa.alloc(u8, 1024));
    defer gpa.free(fba.buffer);

    const input =
        \\This is my new paragraph
        \\I have written in markdown
    ;
    const expected = "This is my new paragraph I have written in markdown";

    var reader = Io.Reader.fixed(input);

    const ast = try Ast.build(&reader, &fba);

    try std.testing.expectEqual(ast.root.base.node, .root);

    const paragraph = ast.root.base.children.items[0].asParagraph();
    const text = paragraph.base.children.items[0].asText();
    try std.testing.expectEqualStrings(expected, text.base.value);
}
