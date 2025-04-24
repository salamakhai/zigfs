const std = @import("std");
const cli = @import("cli");
const cmd = @import("cmd");

/// Registry of all commands available for the CLI application
///
pub const Registry = cli.Registry{
    .commands = &[_]cli.Command{
        cli.Command{
            .name = "ls",
            .description = "List directory contents",
            .usage = "ls [directory]",
            .help =
            \\Lists files and directories in the specified path.
            \\If no path is provided, lists the current directory.
            \\
            \\Examples:
            \\  ls             List current directory
            \\  ls /some/path  List contents of /some/path
            ,
            .execute = cmd.LsFn,
        },

        cli.Command{
            .name = "find",
            .description = "Find files matching a pattern",
            .usage = "find pattern [path]",
            .help =
            \\ Concurent search for files with names containing the specified pattern.
            \\ If no path is provided, searches in the current directory.
            \\
            \\ Examples:
            \\ find test       Find files containing 'test' in current directory
            \\ find .txt /test Find .txt files in /test directory
            ,
            .execute = cmd.FindFn,
        },
    },
};
