const std = @import("std");

/// Unified argument iterator interface
pub const ArgIterator = union(enum) {
    process: ProcessArgIterator,
    string: StringArgIterator,

    pub fn next(self: *ArgIterator) ?[]const u8 {
        return switch (self.*) {
            .process => |*iter| iter.next(),
            .string => |*iter| iter.next(),
        };
    }

    pub fn skip(self: *ArgIterator, count: usize) void {
        switch (self.*) {
            .process => |*iter| iter.skip(count),
            .string => |*iter| iter.skip(count),
        }
    }

    pub fn deinit(self: *ArgIterator) void {
        switch (self.*) {
            .process => |*iter| iter.deinit(),
            .string => |*iter| iter.deinit(),
        }
    }

    // Factories
    pub fn fromProcessArgs(allocator: std.mem.Allocator) !ArgIterator {
        const process_args = try std.process.argsWithAllocator(allocator);
        return ArgIterator{
            .process = ProcessArgIterator{ .inner = process_args },
        };
    }

    pub fn fromString(allocator: std.mem.Allocator, input: []const u8) ArgIterator {
        return ArgIterator{
            .string = StringArgIterator.init(allocator, input),
        };
    }
};

pub const ProcessArgIterator = struct {
    inner: std.process.ArgIterator,

    pub fn next(self: *ProcessArgIterator) ?[]const u8 {
        return self.inner.next();
    }

    pub fn skip(self: *ProcessArgIterator, count: usize) void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (self.inner.next() == null) break;
        }
    }

    pub fn deinit(self: *ProcessArgIterator) void {
        self.inner.deinit();
    }
};

pub const StringArgIterator = struct {
    split_iter: std.mem.SplitIterator(u8, .scalar),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) StringArgIterator {
        return StringArgIterator{
            .split_iter = std.mem.splitScalar(u8, input, ' '),
            .allocator = allocator,
        };
    }

    pub fn next(self: *StringArgIterator) ?[]const u8 {
        while (self.split_iter.next()) |arg| {
            const trimmed = std.mem.trim(u8, arg, " \t");
            if (trimmed.len > 0) {
                return trimmed;
            }
        }
        return null;
    }

    pub fn skip(self: *StringArgIterator, count: usize) void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (self.next() == null) break;
        }
    }

    pub fn deinit(self: *StringArgIterator) void {
        _ = self;
    }
};
