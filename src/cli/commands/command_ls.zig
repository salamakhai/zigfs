const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const NewListAction = @import("../actions/action_list.zig").NewAction;
const NewMountAction = @import("../actions/action_mount.zig").NewAction;

pub const COMMAND = Command{
    .name = "ls",
    .description = "List directory contents",
    .helpFunc = help,
    .execute = execute,
};

fn help(self: *const Action) []const u8 {
    _ = self;
    return 
    \\Usage: ls [path]
    \\
    \\List the contents of a directory.
    \\If no path is provided, lists the current directory (root).
    \\
    \\Examples:
    \\  ls           - List current directory contents
    \\  ls /etc      - List contents of /etc directory
    ;
}

fn execute(
    self: *Command,
    args: ArgIterator,
) anyerror!void {
    const core = self.core;

    const allocator = core.allocator;
    const writer = core.writer;
    const context = try core.allocator.create(Context);

    const mount = NewMountAction();
    const list = NewListAction();

    mount.invoke(context, allocator, args, writer);
    list.invoke(context, allocator, args, writer);
}
