const std = @import("std");
const Io = std.Io;
const lion = @import("lion");

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var input_buf: [1024]u8 = undefined;

    const stdout_file = Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 2) {
        try stdout.writeAll("USAGE: lion <filename>\n");
        try stdout.flush();
        return;
    }

    const file_path = args[1];
    const input_file = try Io.Dir.cwd().openFile(init.io, file_path, .{});
    var input_reader = input_file.reader(init.io, &input_buf);
    const reader = &input_reader.interface;

    const ast = try lion.Ast.build(reader, init.gpa);
    defer ast.deinit(init.gpa);

    const html_renderer = lion.Html.init(.{});
    try html_renderer.render(&ast, stdout);
    try stdout.flush();
}
