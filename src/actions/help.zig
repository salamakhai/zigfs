const std = @import("std");
const cli = @import("cli");

pub const ACTION = cli.Action{
    .name = cli.Core.HELP_ACTION,
    .process = process,
};

fn process(
    self: *cli.Action,
    core: *cli.Core,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = self;
    _ = reader;

    if (args.len == 0) {
        try generalHelp(core, writer);
        return;
    }

    const action_name = args[0];
    if (core.findAction(action_name)) |action| {
        try action.printUsage(writer);
        return;
    }

    try writer.print("Unknown action: {s}\n\n", .{action_name});
    try generalHelp(core, writer);
}

fn generalHelp(core: *cli.Core, writer: cli.Writer) !void {
    try writer.writeAll(
        \\zigfs - Filesystem browser
        \\
        \\Usage: zigfs <action> [args]
        \\
        \\Actions:
        \\
    );

    for (core.actions) |action| {
        try writer.print("  {s:<12} {s}\n", .{ action.name, action.description });
    }

    try writer.writeAll("\nUse 'zigfs help <action>' for more information about an action.\n");
}
