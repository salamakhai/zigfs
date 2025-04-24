const std = @import("std");
const cli = @import("cli");

const Reader = cli.Reader;
const Writer = cli.Writer;
const Error = cli.CliError;
const Command = cli.Command;
const Registry = cli.Registry;
const Runner = cli.Runner;
const SubRunner = cli.SubRunner;

pub const CLI = struct {
    allocator: std.mem.Allocator,
    reader: Reader,
    wirter: Writer,
    runner: Runner,

    registry: *const Registry,
    initialized: bool = false,

    //
    // LIFECYCLE
    //
    pub fn init(
        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,
        registry: *const Registry,
    ) !*CLI {
        var instance = try allocator.create(CLI);

        instance.* = CLI{
            .allocator = allocator,
            .reader = reader,
            .writer = writer,
            .registry = registry,
        };

        instance.initialized = true;
        instance.runner = Runner{
            .runtimeCLI = instance,
        };
        return instance;
    }

    pub fn deinit(self: *CLI) void {
        self.runner.deinit();
        self.allocator.destroy(self);
    }

    //
    // PUBLIC
    //
    pub fn runCmd(self: *CLI, command_name: []const u8, args: []const []const u8) !void {
        const stdout = std.io.getStdOut().writer();

        if (self.registry.findCommand(command_name)) |cmd| {
            try cmd.execute(self.allocator, args, stdout);
        } else {
            return Error.CommandNotFound;
        }
    }
};
