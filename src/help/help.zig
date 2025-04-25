const std = @import("std");
const cli = @import("cli");

const Writer = cli.Writer;
const Command = cli.Command;

pub fn process(
    self: *Command,
    runner: *cli.Runner,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = reader;

    //Generar help
    if (args.len == 0) {
        try generalHelp(self, runner, writer);
        return;
    }

    // Command Help
    const command_name = args[0];

    if (!std.mem.eql(u8, self.name, command_name)) {
        if (runner.core.findCommand(command_name)) |command| {
            try writer.print("Command: {s}\n\n", .{command.name});
            try writer.print("\nDescription:\n{s}\n", .{command.help});
            return;
        }
    }

    try generalHelp(self, runner, writer);
}

fn generalHelp(self: *Command, runner: *cli.Runner, writer: cli.Writer) !void {
    // General Help
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
    );

    for (runner.core.commands) |cmd| {
        if (!std.mem.eql(u8, self.name, cmd.name)) {
            try writer.print("\n  {s: <10} - {s}", .{ cmd.name, cmd.description });
        }
    }

    try writer.writeAll("\n\nUse 'zigfs help [command]' for more information about a command.\n");
}
