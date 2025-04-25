const cli = @import("cli");
const Process = @import("find.zig").process;

pub const cmd = cli.Command{
    .name = "find",
    .description = "find [pattern]",
    .help =
    \\ find [args]
    \\
    \\ Concurent search for files with names containing the specified pattern.
    \\ If no path is provided, searches in the current directory.
    \\
    \\ Examples:
    \\ find test       Find files containing 'test' in current directory
    \\ find .txt /test Find .txt files in /test directory
    ,
    .process = Process,
};
