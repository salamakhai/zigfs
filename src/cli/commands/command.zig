const Core = @import("../core/core.zig").Core;
const ArgIterator = Core.ArgIterator;
const Action = Core.Action;

pub const CommandError = error{};

pub const Command = struct {
    core: *Core,
    name: []const u8,
    description: []const u8,

    helpFunc: *const fn (*const ?Action) []const u8,
    execute: *const fn (*const Command, *const ArgIterator) CommandError!void,
};
