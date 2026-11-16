const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const Ast = @import("Ast.zig");

const Html = @This();

opts: Options,

const Options = struct {
    root_begin: []const u8 = "<article>",
    root_end: []const u8 = "</article>",

    paragraph_begin: []const u8 = "<p>",
    paragraph_end: []const u8 = "</p>",
};

pub fn init(opts: Options) Html {
    return .{ .opts = opts };
}

const Error = Allocator.Error || Io.Writer.Error;

pub fn render(self: Html, ast: *const Ast, w: *Io.Writer) Error!void {
    try self.renderNode(ast.root, w);
}

fn renderNode(self: *const Html, node: *Ast.Node, w: *Io.Writer) Error!void {
    switch (node.*) {
        .root => {
            try w.writeAll(self.opts.root_begin);
            try self.renderParent(node, w);
            try w.writeAll(self.opts.root_end);
        },
        .paragraph => {
            try w.writeAll(self.opts.paragraph_begin);
            try self.renderParent(node, w);
            try w.writeAll(self.opts.paragraph_end);
        },
        .text => {
            try w.writeAll(node.text.value);
        },
        else => @panic("Not implemented"),
    }
}

fn renderParent(self: *const Html, node: *Ast.Node, w: *Io.Writer) Error!void {
    if (node.children()) |children| {
        for (children.items) |child| try self.renderNode(child, w);
    } else unreachable;
}

test "it renders a paragraph" {
    const gpa = std.testing.allocator;
    var out_buf: [1024]u8 = undefined;

    const md =
        \\This is my new paragraph
        \\I have written in markdown
    ;
    const html = "<article><p>This is my new paragraph I have written in markdown</p></article>";

    const html_renderer = init(.{});
    var out_writer = Io.Writer.fixed(&out_buf);
    var reader = Io.Reader.fixed(md);

    var ast = try Ast.build(&reader, gpa);
    defer ast.deinit();

    try html_renderer.render(&ast, &out_writer);

    try std.testing.expectEqualStrings(html, out_writer.buffer[0..html.len]);
}
