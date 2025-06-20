const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Command = Core.Command;
const CommandError = Command.CommandError;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const constants = Core.constants;

pub const COMMAND = Command{
    .name = "help",
    .description = "",
    .getHelp = undefined,
    .execute = execute,
};

fn execute(
    self: *const Command,
    core: *const Core,
    args: *const ArgIterator,
) CommandError!void {
    _ = self;
    const writer = core.writer;
    var args_copy = args.*;

    const command_name = args_copy.next() orelse {
        generalInfo(core, writer);
        return;
    };

    if (std.mem.eql(u8, command_name, constants.HELP_COMMAND)) {
        generalInfo(core, writer);
        return;
    }

    const command = core.findCommand(command_name) orelse {
        writer.print("Error: Unknown command '{s}'\n", .{command_name}) catch {};
        generalInfo(core, writer);
        return;
    };

    commandInfo(command, writer);
}

// Private
fn generalInfo(core: *const Core, writer: Writer) void {
    writer.writeAll(
        \\zigfs - Filesystem browser
        \\
        \\Usage: zigfs <command> [args]
        \\
        \\Commands:
        \\
    ) catch {};

    for (core.commands) |command| {
        if (!std.mem.eql(u8, command.name, constants.HELP_COMMAND)) {
            writer.print("  {s:<12} {s}\n", .{ command.name, command.description }) catch {};
        }
    }

    writer.writeAll("\nUse 'help <command>' for more information about a command.\n") catch {};
}

fn commandInfo(command: *const Command, writer: Writer) void {
    const usageText = command.getHelp();
    writer.print("{s}", .{usageText}) catch {};
}
