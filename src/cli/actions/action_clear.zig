const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn createAction() Action {
    return Action{
        .name = "clear",
        .description = "Clear the terminal screen",
        .invoke = invoke,
    };
}

// Private
fn invoke(
    context: *Context,
    allocator: Allocator,
    arguments: *ArgIterator,
    writer: Writer,
) ActionError!void {
    _ = context;
    _ = allocator;
    _ = arguments;

    // \x1b[2J clears screen
    // \x1b[H moves cursor to top-left corner
    writer.print("\x1b[2J\x1b[H", .{}) catch {
        return ActionError.WriteError;
    };
}