const std = @import("std");

pub const Type = enum {
    blockquote,
    @"break",
    code,
    root,
};

pub const Node = struct {
    type: Type,
};

pub const Parent = struct {
    type: Type,
    children: std.ArrayList(Node),
};

pub const Literal = struct {
    type: Type,
    value: []const u8,
};

pub const Blockquote = struct {
    type: Type = .blockquote,
    children: std.ArrayList(Node) = .empty,
};

pub const Break = struct {
    type: Type = .@"break",
};

pub const Code = struct {
    type: Type = .code,
    value: []const u8,
    lang: ?[]const u8 = null,
    meta: ?[]const u8 = null,
};

pub const Root = struct {
    type: Type = .root,
    children: std.ArrayList(Node),
};

pub fn main(init: std.process.Init) void {
    const blockquote: Blockquote = .{};
    const @"break": Break = .{};
    const code: Code = .{
        .value = "const std = @import(\"std\");\n",
        .lang = "zig",
    };
    const root: Root = .{};

    try root.children.append(init.gpa, blockquote);
    try root.children.append(init.gpa, @"break");
    try root.children.append(init.gpa, code);
}
