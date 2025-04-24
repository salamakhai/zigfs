const std = @import("std");
const cli = @import("cli");

const Command = cli.Command;

pub const Registry = struct {
    commands: []const Command,

    pub fn findCommand(self: *const Registry, name: []const u8) ?*const Command {
        for (self.commands) |*command| {
            if (std.mem.eql(u8, command.name, name)) {
                return command;
            }
        }
        return null;
    }
};
