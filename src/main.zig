const std = @import("std");
const Io = std.Io;
const lion = @import("lion");

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var input_buf: [1024]u8 = undefined;
    var ast_buf: [1024]u8 = undefined;

    const stdout_file = Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 2) {
        try help(stdout);
        return try stdout.flush();
    }

    const input_file = try Io.Dir.cwd().openFile(init.io, args[1], .{});
    var input_reader = input_file.reader(init.io, &input_buf);
    const reader = &input_reader.interface;

    var fba = std.heap.FixedBufferAllocator.init(&ast_buf);
    const ast = try lion.Ast.build(reader, &fba);

    const html_renderer = lion.Html.init(.{});
    try html_renderer.render(&ast, stdout);
    try stdout.flush();
}

fn help(w: *Io.Writer) Io.Writer.Error!void {
    try w.writeAll("USAGE: lion <filename>\n");
}
