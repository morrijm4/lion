const std = @import("std");
const assert = std.debug.assert;

pub const Ast = @import("Ast.zig");
pub const Html = @import("Html.zig");

test {
    @import("std").testing.refAllDecls(@This());
}

test "cases" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    const tests = try std.Io.Dir.cwd().openDir(io, "./test", .{ .iterate = true });
    defer tests.close(io);

    var it = tests.iterate();

    while (try it.next(io)) |entry| {
        if (entry.kind != .directory) {
            return error.InvalidFile;
        }

        if (!std.mem.eql(u8, entry.name, "010-code-block")) continue;

        const case = try tests.openDir(io, entry.name, .{});
        defer case.close(io);

        const md = try case.openFile(io, "input.md", .{});
        defer md.close(io);

        var buf: [4096]u8 = undefined;
        var md_reader = md.reader(io, &buf);
        const reader = &md_reader.interface;

        const ast = try Ast.build(reader, gpa);
        defer ast.deinit();

        const renderer = Html.init(.{});

        var actual = std.Io.Writer.Allocating.init(gpa);
        defer actual.deinit();

        try renderer.render(ast, &actual.writer);

        const html = try case.openFile(io, "output.html", .{});
        defer html.close(io);

        var html_reader = html.reader(io, &buf);
        const expected = try html_reader.interface.allocRemaining(
            gpa,
            .limited(1024 * 1024),
        );
        defer gpa.free(expected);

        std.testing.expectEqualStrings(expected, actual.written()) catch |err| {
            std.debug.print("\n\n=========== Input markdown ===========\n", .{});
            if (case.readFileAlloc(io, "input.md", gpa, .unlimited)) |input| {
                std.debug.print("{s}\n", .{input});
                gpa.free(input);
            } else |_| {
                std.debug.print("Read failure\n", .{});
            }
            std.debug.print("\n\n***** [FAILED CASE] {s} *****\n\n\n", .{entry.name});
            return err;
        };
    }
}
