const std = @import("std");
const types = @import("cli_types");

pub fn printUsage(
    registry: types.cmd.Registry,
    writer: types.cmd.Writer,
) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
    );

    for (registry.commands) |cmd| {
        try writer.print("\n  {s: <10} - {s}", .{ cmd.name, cmd.description });
    }

    try writer.writeAll("\n\nUse 'zigfs help [command]' for more information about a command.\n");
}

pub fn printCommandHelp(
    registry: types.cmd.Registry,
    writer: types.cmd.Writer,
    command_name: []const u8,
) !bool {
    for (registry.commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, command_name)) {
            try writer.print("Command: {s}\n\n", .{cmd.name});
            try writer.print("Usage: zigfs {s}\n\n", .{cmd.usage});
            try writer.print("Description: {s}\n\n", .{cmd.description});
            try writer.print("{s}\n", .{cmd.help});
            return true;
        }
    }

    return false;
}
