const cli = @import("cli");
const Process = @import("mount.zig").process;

pub const cmd = cli.Command{
    .name = "ls",
    .description = "mount [image]",
    .help =
    \\mount [directory]
    \\
    \\
    \\
    \\
    \\Examples:
    \\  
    \\  
    ,
    .process = Process,
};
