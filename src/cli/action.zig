const std = @import("std");

const Core = @import("core.zig").Core;
const SubAction = @import("sub_action.zig").SubAction;
const Reader = std.io.AnyReader;
const Writer = std.io.AnyWriter;

pub const Action = struct {
    name: []const u8,
    description: []const u8 = "",
    help: []const u8 = "",
    interactive: bool = false,
    context: ?*anyopaque = null,
    sub_actions: []const SubAction = &[_]SubAction{},

    process: *const fn (*Action, *Core, []const []const u8, Reader, Writer) anyerror!void,

    pub fn findSubAction(self: *const Action, name: []const u8) ?*const SubAction {
        for (self.sub_actions) |*sub| {
            if (std.mem.eql(u8, sub.name, name)) return sub;
        }
        return null;
    }

    pub fn printUsage(self: *const Action, writer: Writer) !void {
        try writer.print("Usage: {s}\n", .{self.name});
        try writer.print("  {s}\n\n", .{self.description});

        if (self.sub_actions.len > 0) {
            try writer.print("Sub-actions:\n", .{});
            for (self.sub_actions) |sub| {
                try writer.print("  {s:<12} {s}\n", .{ sub.name, sub.description });
            }
            try writer.print("\n", .{});
        }

        try writer.print("{s}\n", .{self.help});
    }
};
