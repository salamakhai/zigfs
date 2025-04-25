const std = @import("std");
const cli = @import("cli");

const LsProcess = @import("ls/ls.zig").process;
const FindProcess = @import("find/find.zig").process;

/// Registry of all commands available for the CLI application
///
pub const commands = &[_]cli.Command{
    cli.Command{
        .name = "ls",
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
        .process = LsProcess,
    },

    cli.Command{
        .name = "find",
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
        .process = FindProcess,
    },
};
