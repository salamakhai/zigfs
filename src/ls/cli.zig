const cli = @import("cli");
const Process = @import("ls.zig").process;

pub const cmd = cli.Command{
    .name = "ls",
    .description = "ls [directory]",
    .help =
    \\ls [directory]
    \\
    \\Lists files and directories in the specified path.
    \\If no path is provided, lists the current directory.
    \\
    \\Examples:
    \\  ls             List current directory
    \\  ls /some/path  List contents of /some/path
    ,
    .process = Process,
};
