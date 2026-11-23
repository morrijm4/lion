const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Ast = @import("Ast.zig");
const Type = @import("Type.zig").Type;

const Html = @This();

opts: Options,

const Tag = struct {
    begin: []const u8,
    end: []const u8,
};

const Tags = struct {
    blockquote: Tag = .{
        .begin = "<blockquote>",
        .end = "</blockquote>",
    },
    @"break": Tag = .{
        .begin = "<br />",
        .end = "",
    },
    code: Tag = .{
        .begin = "<pre>",
        .end = "</pre>",
    },
    emphasis: Tag = .{
        .begin = "<em>",
        .end = "</em>",
    },
    heading: Tag = .{
        .begin = "", // TODO: This shouldn't be hardcoded
        .end = "",
    },
    html: Tag = .{
        .begin = "",
        .end = "",
    },
    inline_code: Tag = .{
        .begin = "<code>",
        .end = "</code>",
    },
    list: Tag = .{
        .begin = "<ul>", // TODO: impl ordered lists
        .end = "</ul>",
    },
    list_item: Tag = .{
        .begin = "<li>",
        .end = "</li>",
    },
    paragraph: Tag = .{
        .begin = "<p>\n",
        .end = "</p>\n",
    },
    root: Tag = .{
        .begin = "<article>\n",
        .end = "</article>\n",
    },
    strong: Tag = .{
        .begin = "<strong>",
        .end = "</strong",
    },
    text: Tag = .{
        .begin = "",
        .end = "\n",
    },
};

const Options = struct {
    tags: Tags = .{},
    indent: []const u8 = "    ",
    depth: u8 = 0,
};

pub fn init(opts: Options) Html {
    return .{ .opts = opts };
}

const Error = Io.Writer.Error || error{MaxDepthReached};

pub fn render(self: *const Html, ast: Ast, writer: *Io.Writer) Error!void {
    try self.renderNode(ast.root, writer, self.opts.depth);
}

pub fn renderNode(
    self: *const Html,
    node: *Ast.Node,
    writer: *Io.Writer,
    depth: u8,
) Error!void {
    const t = self.tag(std.meta.activeTag(node.*));
    try self.renderIndent(writer, depth);

    switch (node.*) {
        .heading => |h| {
            switch (h.depth) {
                1 => try writer.writeAll("<h1>\n"),
                2 => try writer.writeAll("<h2>\n"),
                3 => try writer.writeAll("<h3>\n"),
                4 => try writer.writeAll("<h4>\n"),
                5 => try writer.writeAll("<h5>\n"),
                6 => try writer.writeAll("<h6>\n"),
                else => @panic("Invalid depth"),
            }
        },
        else => try writer.writeAll(t.begin),
    }

    switch (node.*) {
        inline else => |*n| {
            const T = @TypeOf(n.*);
            if (@hasField(T, "children")) {
                for (n.children.items) |child| {
                    try self.renderNode(child, writer, depth + 1);
                }
            }
            if (@hasField(T, "value")) {
                try writer.writeAll(n.value);
            }
        },
    }

    switch (node.*) {
        .text => try writer.writeAll(t.end),
        .heading => |h| {
            try self.renderIndent(writer, depth);
            switch (h.depth) {
                1 => try writer.writeAll("</h1>\n"),
                2 => try writer.writeAll("</h2>\n"),
                3 => try writer.writeAll("</h3>\n"),
                4 => try writer.writeAll("</h4>\n"),
                5 => try writer.writeAll("</h5>\n"),
                6 => try writer.writeAll("</h6>\n"),
                else => @panic("Invalid depth"),
            }
        },
        else => {
            try self.renderIndent(writer, depth);
            try writer.writeAll(t.end);
        },
    }
}

pub fn renderIndent(self: *const Html, writer: *Io.Writer, depth: u8) Error!void {
    if (depth == std.math.maxInt(u8)) return error.MaxDepthReached;
    for (0..depth) |_| {
        try writer.writeAll(self.opts.indent);
    }
}

fn tag(self: *const Html, t: Type) Tag {
    return switch (t) {
        inline else => |k| @field(self.opts.tags, @tagName(k)),
    };
}

test "it renders a paragraph" {
    const gpa = std.testing.allocator;
    var out_buf: [1024]u8 = undefined;

    const md =
        \\This is my new paragraph
        \\I have written in markdown
    ;
    const html =
        \\<article>
        \\    <p>
        \\        This is my new paragraph
        \\        I have written in markdown
        \\    </p>
        \\</article>
    ;

    const html_renderer = init(.{});
    var out_writer = Io.Writer.fixed(&out_buf);
    var reader = Io.Reader.fixed(md);

    var ast = try Ast.build(&reader, gpa);
    defer ast.deinit();

    try html_renderer.render(ast, &out_writer);

    try std.testing.expectEqualStrings(html, out_writer.buffer[0..html.len]);
}
