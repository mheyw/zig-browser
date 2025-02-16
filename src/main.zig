// src/main.zig
const std = @import("std");

// Use relative imports
pub const engine = @import("engine/engine.zig");
pub const dom = @import("dom/node.zig");
pub const html = @import("html/parser.zig");
pub const errors = @import("errors.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Zig Browser starting up...\n", .{});
    _ = allocator;
}

test {
    @import("std").testing.refAllDecls(@This());
}
