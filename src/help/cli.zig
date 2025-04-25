const cli = @import("cli");
const Process = @import("help.zig").process;

pub const cmd = cli.Command{
    .name = cli.Core.HELP_COMMAND,
    .description = "help or help [command]",
    .help = undefined,
    .process = Process,
};
