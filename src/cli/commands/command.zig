const Core = @import("../core/core.zig").Core;
const ArgIterator = Core.ArgIterator;
const Action = Core.Action;

pub const Command = struct {
    pub const CommandError = error{
        OutOfMemory,
        FileNotFound,
        AccessDenied,
        InvalidPath,
        NotDirectory,
        NotFile,
        EntryNotFound,
        ReadError,
        WriteError,
        UnsupportedFormat,
    };

    name: []const u8,
    description: []const u8,

    getHelp: *const fn () []const u8,
    execute: *const fn (
        *const Command,
        *const Core,
        *const ArgIterator,
    ) CommandError!void,
};
