const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;

pub const Ast = @This();

root: Node,

pub fn init() Ast {
    return .{
        .root = .{ .root = {} },
    };
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
    //  paragraph,
    root,
    //  strong,
    text,
};

pub const Node = union(Type) {
    blockquote: void,
    @"break": void,
    code: struct { lang: ?[]const u8, meta: ?[]const u8 },
    emphasis: void,
    heading: struct { depth: u3 },
    root: void,
    text: void,

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
            .root,
            => true,

            // Nodes
            .@"break",
            => false,
        };
    }

    pub fn asLiteral(self: *Node) *Literal {
        assert(self.isLiteral());
        return @fieldParentPtr("node", self);
    }

    pub fn asParent(self: *Node) *Parent {
        assert(self.isParent());
        return @fieldParentPtr("node", self);
    }
};

pub const Literal = struct {
    node: Node,
    value: []const u8,
};

pub const Parent = struct {
    node: Node,
    children: []*Node,
};
