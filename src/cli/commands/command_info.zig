const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const NewMountAction = @import("../actions/action_mount.zig").NewAction;
const NewInfoAction = @import("../actions/action_info.zig").NewAction;

pub const COMMAND = Command{
    .name = "info",
    .description = "Display detailed information about a filesystem image",
    .getHelp = help,
    .execute = execute,
};

fn help() []const u8 {
    return 
    \\Usage: info [file_system_image]
    \\
    \\Display detailed information about a filesystem image.
    \\
    \\Examples:
    \\  info disk.img - Mount and show info for disk.img
    \\
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
    const mount = NewMountAction();
    const info = NewInfoAction();

    var context = Context.init();
    defer context.deinit();

    var args_copy = args.*;

    try mount.invoke(&context, allocator, &args_copy, writer);
    writer.print("\n", .{}) catch {};
    try info.invoke(&context, allocator, &args_copy, writer);
}
