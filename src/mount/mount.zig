const std = @import("std");
const cli = @import("cli");

pub fn process(
    self: *cli.Command,
    runner: *cli.Runner,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = self;
    _ = runner;
    _ = args;
    _ = reader;
    _ = writer;
}
