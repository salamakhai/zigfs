const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Colors = Core.Colors;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const NewCatAction = @import("../actions/action_cat.zig").CreateAction;
const NewMountAction = @import("../actions/action_mount.zig").CreateAction;
const NewInfoAction = @import("../actions/action_info.zig").CreateAction;
const NewListAction = @import("../actions/action_list.zig").CreateAction;
const NewCdAction = @import("../actions/action_cd.zig").CreateAction;
const NewClearAction = @import("../actions/action_clear.zig").CreateAction;

pub const COMMAND = Command{
    .name = "browse",
    .description = "Interactive FileSystem browser",
    .getHelp = help,
    .execute = execute,
};

const ROOT_DIRECTORY: []const u8 = "/";

fn help() []const u8 {
    return 
    \\Usage: browse [file_system_image]
    \\
    \\Interactive FileSystem browser.
    \\
    \\Examples:
    \\  browse filesystem.img
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
    const reader = core.reader;
    const mount = NewMountAction();

    const actions_registry = [_]Action{
        NewInfoAction(),
        NewListAction(),
        NewCdAction(),
        NewCatAction(),
        NewClearAction(),
    };

    var context = Context.init();
    defer context.deinit();

    var args_copy = args.*;

    try mount.invoke(&context, allocator, &args_copy, writer);

    // Interactive loop
    printSubCommandsHelp(writer, &actions_registry);

    var buffer: [256]u8 = undefined;

    while (true) {
        printPromt(writer, &context);

        if (reader.readUntilDelimiterOrEof(buffer[0..], '\n') catch null) |input| {
            const trimmed_input = std.mem.trim(u8, input, " \t\r\n");
            if (trimmed_input.len == 0) {
                continue;
            }
            if (IsWaitingExit(trimmed_input)) {
                break;
            }

            var arg_iterator = ArgIterator.fromString(allocator, trimmed_input);
            defer arg_iterator.deinit();

            handleSubCommand(
                &context,
                allocator,
                writer,
                &arg_iterator,
                &actions_registry,
            );
        } else {
            break;
        }
    }
}

// Gui
fn printPromt(writer: Core.Writer, context: *Context) void {
    const mark = ">";
    const prompt = "%";

    if (context.filesystem) |fs_ctx| {
        const current_dir = fs_ctx.session.getCurrentDirectory();
        const fs_name = fs_ctx.filesystem.getOwnedName();

        writer.print("{s}{s}{s} {s}{s}{s} {s}~{s}{s} {s}{s}{s} ", .{
            Colors.get(Colors.magenta), mark,        Colors.get(Colors.reset),
            Colors.get(Colors.yellow),  fs_name,     Colors.get(Colors.reset),
            Colors.get(Colors.cyan),    current_dir, Colors.get(Colors.reset),
            Colors.get(Colors.bold),    prompt,      Colors.get(Colors.reset),
        }) catch {};
    } else {
        writer.print("??? {s}{s}{s} ", .{ Colors.get(Colors.cyan), prompt, Colors.get(Colors.reset) }) catch {};
    }
}

fn printSubCommandsHelp(writer: Core.Writer, actions_registry: []const Action) void {
    writer.writeAll("\nAvailable commands:\n") catch {};
    writer.writeAll("  help         - Show this help message\n") catch {};

    for (actions_registry) |action| {
        writer.print("  {s:<12} - {s}\n", .{ action.name, action.description }) catch {};
    }

    writer.writeAll("  exit/quit    - Exit the browser\n\n") catch {};
}

fn printBlankLine(writer: Core.Writer) void {
    writer.print("\n", .{}) catch {};
}

// Helpers
fn IsWaitingExit(input: []const u8) bool {
    return std.mem.eql(u8, input, "exit") or
        std.mem.eql(u8, input, "quit") or
        std.mem.eql(u8, input, "q");
}

fn findAction(actions_registry: []const Action, name: []const u8) ?*const Action {
    for (actions_registry) |*action| {
        if (std.mem.eql(u8, action.name, name)) {
            return action;
        }
    }
    return null;
}

fn handleSubCommand(
    context: *Context,
    allocator: std.mem.Allocator,
    writer: Core.Writer,
    arg_iterator: *ArgIterator,
    actions_registry: []const Action,
) void {
    const command = arg_iterator.next() orelse {
        return;
    };

    if (std.mem.eql(u8, command, "help")) {
        printSubCommandsHelp(writer, actions_registry);
        return;
    }

    const action = findAction(actions_registry, command) orelse {
        writer.print("Unknown command: {s}\n", .{command}) catch {};
        writer.print("Type 'help' for available commands\n", .{}) catch {};
        return;
    };

    action.invoke(context, allocator, arg_iterator, writer) catch {};
}
