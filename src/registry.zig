const std = @import("std");
const cli = @import("cli");

const help = @import("help/help.zig").Command;
const ls = @import("ls/ls.zig").Command;
const find = @import("find/find.zig").Command;
const browse = @import("browse/browse.zig").Command;

/// Registry of all commands available for the CLI application
pub const commands = &[_]cli.Command{
    help,
    ls,
    find,
    browse,
};
