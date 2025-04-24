const std = @import("std");
const cli = @import("cli");

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    help: []const u8,

    function: Func,

    pub const Func = *const fn (
        allocator: std.mem.Allocator,
        args: []const []const u8,
        writer: cli.Writer,
    ) anyerror!void;
};
