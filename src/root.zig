const std = @import("std");
const assert = std.debug.assert;

pub const Ast = @import("Ast.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
