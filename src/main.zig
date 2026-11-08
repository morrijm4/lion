const std = @import("std");
const lion = @import("lion");

const Node = lion.Ast.Node;
const Literal = lion.Ast.Literal;
const Parent = lion.Ast.Parent;

const print = std.debug.print;

pub fn main() !void {
    var himom: Literal = .{
        .node = .{ .text = {} },
        .value = "Hi, mom!",
    };

    var title: Literal = .{
        .node = .{ .text = {} },
        .value = "This is my family",
    };

    var arr = [_]*Node{&title.node};
    const ns: []*Node = &arr;
    var mother: Parent = .{
        .node = .{ .heading = .{ .depth = 3 } },
        .children = ns,
    };

    const nodes: [2]*Node = .{
        &mother.node,
        &himom.node,
    };

    for (nodes) |node| printNode(node);
}

fn printNode(node: *Node) void {
    if (node.isParent()) {
        const parent = node.asParent();

        switch (parent.node) {
            .heading => |h| {
                for (0..h.depth) |_| print("#", .{});
                print(" ", .{});
            },
            else => {},
        }

        for (parent.children) |child| {
            printNode(child);
        }
        return;
    }

    if (node.isLiteral()) {
        const literal = node.asLiteral();
        switch (literal.node) {
            .text => print("{s}\n", .{literal.value}),
            else => {},
        }
        return;
    }

    unreachable;
}
