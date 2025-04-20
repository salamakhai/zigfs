const std = @import("std");
const cmd_help = @import("internal/help.zig");
const cmd_handler = @import("internal/handler.zig");
const types = @import("internal/types.zig");

// Public
pub const Writer = types.Writer;

// :o Declaration of types for cli extension!
pub const Registry = types.Registry;
pub const Command = types.Command;
pub const CommandFn = types.CommandFn;
pub const CliError = types.CliError;

pub const handleCmdArgs = cmd_handler.handleArgs;
pub const printInfo = cmd_help.printInfo;
pub const printCommandHelp = cmd_help.printCommandHelp;
