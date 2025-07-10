const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const newCatAction = @import("../actions/action_cat.zig").createAction;
const newMountAction = @import("../actions/action_mount.zig").createAction;

pub const COMMAND = Command{
    .name = "cat",
    .description = "Extract data from a file",
    .getHelp = help,
    .execute = execute,
};

fn help() []const u8 {
    return 
    \\Usage: cat [file_system_image] [file_path] [output_file]
    \\
    \\Extract file data from the filesystem.
    \\If no output file is provided, data is written to stdout.
    \\
    \\Examples:
    \\  cut /hello.txt         - Extract and display file contents
    \\  cut /hello.txt out.txt - Extract file to out.txt
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
    const mount = newMountAction();
    const cat = newCatAction();

    var context = Context.init();
    defer context.deinit();

    var args_copy = args.*;

    try mount.invoke(&context, allocator, &args_copy, writer);
    writer.print("\n", .{}) catch {};
    try cat.invoke(&context, allocator, &args_copy, writer);
}
