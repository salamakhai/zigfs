const std = @import("std");

const Core = @import("core.zig").Core;
const Allocator = Core.Allocator;
const ArgIterator = Core.ArgIterator;

pub const ParserError = error{
    InvalidInput,
};

pub fn readLine(core: *Core) u8 {
    _ = core;
}

pub fn tokenize(input: []const u8) ParserError!ArgIterator {
    const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

    if (trimmed.len == 0) {
        return ParserError.InvalidInput;
    }

    const args_iter = std.mem.tokenizeAny(u8, trimmed, " \t");
    return args_iter;
}

pub fn nextArg(allocator: *Allocator, iterator: *ArgIterator) !u8 {
    _ = allocator;
    _ = iterator;
}
