const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const ArgIterator = Core.ArgIterator;
const Command = Core.Command;
const Action = Core.Action;

const CommandError = Command.CommandError;

const NewCutAction = @import("../actions/action_cut.zig").NewAction;
const NewMountAction = @import("../actions/action_mount.zig").NewAction;
const NewInfoAction = @import("../actions/action_info.zig").NewAction;
const NewListAction = @import("../actions/action_list.zig").NewAction;

pub const COMMAND = Command{
    .name = "browse",
    .description = "Interactive FileSystem browser",
    .getHelp = help,
    .execute = execute,
};

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

    const prompt = "> ";

    const allocator = core.allocator;
    const writer = core.writer;
    const reader = core.reader;
    const mount = NewMountAction();

    const actions_registry = [_]Action{
        NewCutAction(),
        NewInfoAction(),
        NewListAction(),
    };

    var context = Context.init();
    defer context.deinit();

    var args_copy = args.*;

    try mount.invoke(&context, allocator, &args_copy, writer);

    // Interactive loop
    printSubCommandsHelp(writer, &actions_registry);

    var buffer: [256]u8 = undefined;

    while (true) {
        writer.print("{s}", .{prompt}) catch {};

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
        writer.print("Type 'help' for available commands.\n", .{}) catch {};
        return;
    };

    printBlankLine(writer);
    action.invoke(context, allocator, arg_iterator, writer) catch |err| {
        writer.print("Action '{s}' executing failed: {!}\n", .{ action.name, err }) catch {};
    };
    printBlankLine(writer);
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
