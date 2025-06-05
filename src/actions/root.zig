const std = @import("std");
const cli = @import("cli");

const help = @import("help.zig").ACTION;
const browse = @import("browse/browse.zig").ACTION;

/// Registry of all actions available for the application
pub const actions = &[_]cli.Action{
    help,
    browse,
};
