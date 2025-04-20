const std = @import("std");

pub const Writer = std.fs.File.Writer;

pub const CliError = error{
    UnknownCommand,
    CommandFailed,
    InvalidArgument,
    OutOfMemory,
};

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

pub const CommandFn = *const fn (
    allocator: std.mem.Allocator,
    args: []const []const u8,
    writer: Writer,
) anyerror!void;

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    help: []const u8,

    execute: CommandFn,
};
