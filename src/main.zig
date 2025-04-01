const std = @import("std");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());

    defer arena.deinit();
    defer _ = gpa.deinit();

    const allocator = arena.allocator();
    try cli.handleArgs(allocator);
}
