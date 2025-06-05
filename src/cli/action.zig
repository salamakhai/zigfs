const std = @import("std");

const Reader = std.io.AnyReader;
const Writer = std.io.AnyWriter;

const Core = @import("core.zig").Core;

pub const Action = struct {
    name: []const u8,
    description: []const u8 = "",
    help: *const fn (*const Action) []const u8 = defaultHelp,
    interactive: bool = false,
    context: ?*anyopaque = null,
    children: []const *const Action = &[_]*const Action{},

    process: *const fn (*Action, *Core, []const []const u8, Reader, Writer) anyerror!void,

    pub fn findChild(self: *const Action, name: []const u8) ?*const Action {
        for (self.children) |child| {
            if (std.mem.eql(u8, child.name, name)) return child;
        }
        return null;
    }

    pub fn printUsage(self: *const Action, writer: Writer) !void {
        try writer.print("Usage: {s}\n", .{self.name});
        try writer.print("  {s}\n\n", .{self.description});

        if (self.children.len > 0) {
            try writer.print("Available commands:\n", .{});
            for (self.children) |child| {
                try writer.print("  {s:<12} {s}\n", .{ child.name, child.description });
            }
            try writer.print("\n", .{});
        }

        const help_text = self.help(self);
        try writer.print("{s}\n", .{help_text});
    }

    fn defaultHelp(self: *const Action) []const u8 {
        _ = self;
        return "";
    }
};
