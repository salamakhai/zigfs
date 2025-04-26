const cli = @import("cli");

pub const SubCommand = struct {
    name: []const u8,
    description: []const u8,
    help: []const u8,

    process: SubProcessor,

    pub const SubProcessor = *const fn (
        self: *SubCommand,
        command: *cli.Command,
        args: []const []const u8,
        reader: cli.Reader,
        writer: cli.Writer,
    ) anyerror!void;
};
