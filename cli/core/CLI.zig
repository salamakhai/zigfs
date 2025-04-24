const std = @import("std");
const cli = @import("cli");

const command = cli.Command;

// used
pub const CLI = struct {
    pub fn init() !void {
        // init runners
    }

    pub fn deinit() !void {
        // deinit runners
    }

    pub fn runCmd(cmd: Command) anyerror!void {
        // cmd.runner()
    }
};
