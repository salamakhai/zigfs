const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const NewCutAction = @import("../actions/action_cut.zig").NewAction;
const NewMountAction = @import("../actions/action_mount.zig").NewAction;

pub const COMMAND = Command{
    .name = "cut",
    .description = "Extract data from a file",
    .getHelp = help,
    .execute = execute,
};

fn help() []const u8 {
    return 
    \\Usage: cut <file_path> [output_file]
    \\
    \\Extract file data from the filesystem.
    \\If no output file is provided, data is written to stdout.
    \\
    \\Examples:
    \\  cut /hello.txt         - Extract and display file contents
    \\  cut /hello.txt out.txt - Extract file to out.txt
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
    const cut = NewCutAction();

    const context = core.allocator.create(Context) catch {
        return CommandError.OutOfMemory;
    };
    defer core.allocator.destroy(context);

    var args_copy = args.*;

    try mount.invoke(context, allocator, &args_copy, writer);
    writer.print("\n", .{}) catch {};
    try cut.invoke(context, allocator, &args_copy, writer);
}
