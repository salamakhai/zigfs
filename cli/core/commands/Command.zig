const std = @import("std");
const cli = @import("cli");

pub const Command = struct {
    name: []const u8,
    help: []const u8,

    process: Processor,
    subCommands: []const cli.SubCommand = undefined,

    pub const Processor = *const fn (
        runner: *cli.Runner,
        args: []const []const u8,
        reader: cli.Reader,
        writer: cli.Writer,
    ) anyerror!void;

    pub fn isInteractive(self: *const Command) !bool {
        return self.subCommands.len > 0;
    }

    pub fn findSubCommand(self: *const Command, name: []const u8) ?*const cli.SubCommand {
        for (self.subCommands) |*subCommand| {
            if (std.mem.eql(u8, subCommand.name, name)) {
                return subCommand;
            }
        }
        return null;
    }
};
