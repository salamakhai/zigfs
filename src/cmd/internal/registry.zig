const std = @import("std");
const types = @import("cli_types");

const ls = @import("ls.zig");
const cd = @import("cd.zig");
const find = @import("find.zig");

pub const Registry = types.cmd.Registry{
    .commands = &commands,
};

// ----PRIVATE----
const commands = [_]types.cmd.Command{
    types.cmd.Command{
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
        .execute = ls.execute,
    },

    types.cmd.Command{
        .name = "cd",
        .description = "Change current directory",
        .usage = "cd [directory]",
        .help =
        \\Changes the current working directory.
        \\If no path is provided, changes to home directory.
        \\
        \\Examples:
        \\  cd             Change to home directory
        \\  cd /some/path  Change to /some/path
        \\  cd ..          Move up one directory
        ,
        .execute = cd.execute,
    },

    types.cmd.Command{
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
        .execute = find.execute,
    },
};
