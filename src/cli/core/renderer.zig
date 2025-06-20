const Core = @import("../core/core.zig").Core;
const Allocator = Core.Allocator;
const Reader = Core.Reader;
const Writer = Core.Writer;

pub fn newLine(core: *Core, prefix: []const u8) void {
    _ = core;
    _ = prefix;
}
