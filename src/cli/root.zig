pub const Core = @import("core/core.zig").Core;
pub const Command = Core.Command;
pub const Action = Core.Action;

pub const command_help = @import("commands/command_help.zig").COMMAND;
pub const command_info = @import("commands/command_info.zig").COMMAND;
pub const command_ls = @import("commands/command_ls.zig").COMMAND;
pub const command_cat = @import("commands/command_cat.zig").COMMAND;
pub const command_browse = @import("commands/command_browse.zig").COMMAND;
