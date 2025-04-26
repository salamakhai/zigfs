const std = @import("std");
const cli = @import("cli");

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    help: []const u8,

    process: Processor,

    interactive: bool = false,
    context: *anyopaque = undefined,
    subCommands: []cli.SubCommand = undefined,

    pub const Processor = *const fn (
        self: *Command,
        runner: *cli.Runner,
        args: []const []const u8,
        reader: cli.Reader,
        writer: cli.Writer,
    ) anyerror!void;

    pub fn findSubCommand(self: *const Command, name: []const u8) ?*cli.SubCommand {
        for (self.subCommands) |*subCommand| {
            if (std.mem.eql(u8, subCommand.name, name)) {
                return subCommand;
            }
        }
        return null;
    }

    // PrintInfo
    // PrintUsage

};
