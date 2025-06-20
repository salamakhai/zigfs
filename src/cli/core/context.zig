pub const Context = struct {
    context: ?*anyopaque = null,

    pub fn castTo(self: *Context, T: type) anyerror!*T {
        return @as(*T, @ptrCast(@alignCast(self.context.?)));
    }

    pub fn newFrom(self: *Context, ctx: *anyopaque) void {
        self.context = ctx;
    }
};
