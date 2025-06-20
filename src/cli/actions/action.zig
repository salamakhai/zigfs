const Core = @import("../core/core.zig").Core;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const AgrIterator = Core.ArgIterator;
const CommandError = Core.Command.CommandError;

pub const Action = struct {
    pub const ActionError = CommandError;

    name: []const u8,
    description: []const u8,
    invoke: *const fn (
        *Context,
        Allocator,
        *AgrIterator,
        Writer,
    ) ActionError!void,
};
