const std = @import("std");
const cli = @import("cli");

const Writer = cli.Writer;
const Command = cli.Command;

pub fn printHelp(
    commands: []const Command,
    writer: Writer,
) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
    );

    for (commands) |cmd| {
        try writer.print("\n  {s: <10} - {s}", .{ cmd.name, cmd.help });
    }

    try writer.writeAll("\n\nUse 'zigfs help [command]' for more information about a command.\n");
}

pub fn printCmdHelp(
    commands: []const Command,
    writer: Writer,
    command_name: []const u8,
) !bool {
    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, command_name)) {
            try writer.print("Command: {s}\n\n", .{cmd.name});
            try writer.print("\nDescription:\n{s}\n", .{cmd.help});
            return true;
        }
    }

    return false;
}
