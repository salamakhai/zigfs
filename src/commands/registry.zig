const std = @import("std");
const cli = @import("cli");

const help = @import("help.zig").Command;
const ls = @import("ls.zig").Command;
const find = @import("find.zig").Command;

const mount = @import("mount/mount.zig").Command;

/// Registry of all commands available for the application
pub const commands = &[_]cli.Command{
    help,
    ls,
    find,
    mount,
};
