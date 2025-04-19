const std = @import("std");

const ls = @import("fs-commands/ls.zig");
const cd = @import("fs-commands/cd.zig");


pub const Writer = std.fs.File.Writer;

pub const CliError = error{
    UnknownCommand,
    CommandFailed,
    MissingRequiredArgument,
    InvalidArgument,
    OutOfMemory,
};

/// Command function
pub const CommandFn = *const fn (
    allocator: std.mem.Allocator,
    args: []const []const u8,
    writer: Writer,
) anyerror!void;

/// Command metadata
pub const Command = struct {
    /// Command name used in CLI
    name: []const u8,
    
    /// Short description for help text
    description: []const u8,
    
    /// Usage example
    usage: []const u8,
    
    /// Help text with detailed explanation
    help: []const u8,
    
    /// The function to execute this command
    execute: CommandFn,
};

/// Registry of all available commands
pub const commands = [_]Command{
    Command{
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

    Command{
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
};

/// Print general usage information
pub fn printUsage(writer: Writer) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
    );
    
    for (commands) |cmd| {
        try writer.print("\n  {s: <10} - {s}", .{cmd.name, cmd.description});
    }
    
    try writer.writeAll("\n\nUse 'zigfs help [command]' for more information about a command.\n");
}

/// Print detailed help for a specific command
pub fn printCommandHelp(writer: Writer, command_name: []const u8) !bool {
    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, command_name)) {
            try writer.print("Command: {s}\n\n", .{cmd.name});
            try writer.print("Usage: zigfs {s}\n\n", .{cmd.usage});
            try writer.print("Description: {s}\n\n", .{cmd.description});
            try writer.print("{s}\n", .{cmd.help});
            return true;
        }
    }
    
    return false;
}

fn findCommand(name: []const u8) ?*const Command {
    for (&commands) |*cmd| {
        if (std.mem.eql(u8, cmd.name, name)) {
            return cmd;
        }
    }
    return null;
}

/// Main function to handle command line arguments
pub fn handleArgs(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    
    // Parse command line arguments
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    
    // Skip program name
    _ = args_iter.skip();
    
    // Get command name or show usage if none
    const command_name = args_iter.next() orelse {
        try printUsage(stdout);
        return;
    };
    
    if (std.mem.eql(u8, command_name, "help")) {
        const help_topic = args_iter.next();
        if (help_topic) |topic| {
            const found = try printCommandHelp(stdout, topic);
            if (!found) {
                try stdout.print("Unknown command: '{s}'\n\n", .{topic});
                try printUsage(stdout);
                std.process.exit(1);
            }
        } else {
            try printUsage(stdout);
        }
        return;
    }
    
    // Handle command execution
    if (findCommand(command_name)) |cmd| {
        // Remaining arguments
        var command_args = std.ArrayList([]const u8).init(allocator);
        defer command_args.deinit();
        
        while (args_iter.next()) |arg| {
            try command_args.append(arg);
        }
        
        // Execute command
        cmd.execute(allocator, command_args.items, stdout) catch |err| {
            try stdout.print("Error executing '{s}': {s}\n", .{command_name, @errorName(err)});
            std.process.exit(1);
        };
        return;
    }
    
    // Command not found
    try printUsage(stdout);
    try stdout.print("Error: Unknown command '{s}'\n", .{command_name});
    std.process.exit(1);
}
