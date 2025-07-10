const std = @import("std");

const fslib = @import("fslib");
const FileSystem = fslib.FileSystem;

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const newListAction = @import("../actions/action_list.zig").createAction;
const newMountAction = @import("../actions/action_mount.zig").createAction;

pub const COMMAND = Command{
    .name = "ls",
    .description = "List directory contents",
    .getHelp = help,
    .execute = execute,
};

fn help() []const u8 {
    return 
    \\Usage: ls [file_system_image] [path]
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
    self: *const Command,
    core: *const Core,
    args: *const ArgIterator,
) CommandError!void {
    _ = self;

    const allocator = core.allocator;
    const writer = core.writer;
    const mount = newMountAction();
    const list = newListAction();

    var context = Context.init();
    defer context.deinit();

    var args_copy = args.*;

    try mount.invoke(&context, allocator, &args_copy, writer);
    writer.print("\n", .{}) catch {};
    try list.invoke(&context, allocator, &args_copy, writer);
}
