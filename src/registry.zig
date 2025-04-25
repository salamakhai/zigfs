const std = @import("std");
const cli = @import("cli");

const help = @import("help/cli.zig").cmd;
const ls = @import("ls/cli.zig").cmd;
const find = @import("find/cli.zig").cmd;
const mount = @import("mount/cli.zig").cmd;

/// Registry of all commands available for the CLI application
pub const commands = &[_]cli.Command{
    help,
    ls,
    find,
    mount,
};
