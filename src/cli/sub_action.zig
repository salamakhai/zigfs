const std = @import("std");

// Forward declarations to avoid circular imports
const Action = @import("action.zig").Action;
const Reader = std.io.AnyReader;
const Writer = std.io.AnyWriter;

pub const SubAction = struct {
    name: []const u8,
    description: []const u8,
    help: []const u8,

    process: *const fn (*const SubAction, *Action, []const []const u8, Reader, Writer) anyerror!void,

    pub fn printUsage(self: *const SubAction, writer: Writer) !void {
        try writer.print("Usage: {s}\n", .{self.name});
        try writer.print("  {s}\n\n", .{self.description});
        try writer.print("{s}\n", .{self.help});
    }
};
