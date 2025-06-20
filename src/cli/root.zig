const std = @import("std");

pub const Core = @import("core/core.zig").Core;
pub const Command = Core.Command;
pub const Action = Core.Action;

pub const commands = &[_]Command{
    @import("commands/command_info.zig").COMMAND,
    @import("commands/command_ls.zig").COMMAND,
};

pub fn InitCore(
    allocator: Core.Allocator,
    reader: Core.Reader,
    writer: Core.Writer,
) !*Core {
    const core = try Core.init(
        allocator,
        reader,
        writer,
        commands,
    );

    return core;
}
