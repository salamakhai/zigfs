const std = @import("std");
const cli = @import("cli");
const Image = @import("data/Image.zig").Image;
const ImageError = @import("data/Image.zig").ImageError;
const Allocator = std.mem.Allocator;
const fs = std.fs;

pub fn process(
    _: *cli.Command,
    runner: *cli.Runner,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = reader;

    if (args.len == 0) {
        return;
    }

    const image_path = args[0];

    try writer.print("Mounting image: {s}...\n", .{image_path});

    // Open the image file
    const file = fs.cwd().openFile(image_path, .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => {
                try writer.print("Error: Image file not found: {s}\n", .{image_path});
                return;
            },
            error.AccessDenied => {
                try writer.print("Error: Permission denied accessing: {s}\n", .{image_path});
                return;
            },
            else => {
                try writer.print("Error opening file: {any}\n", .{err});
                return;
            },
        }
    };
    errdefer file.close();

    // Process the ext4 image
    const mounted_image = Image.open(runner.core.allocator, file) catch |err| {
        switch (err) {
            ImageError.InvalidMagicNumber, ImageError.NotExt4Format => {
                try writer.print("Error: Not a valid ext4 filesystem: {s}\n", .{image_path});
                return;
            },
            ImageError.InvalidBlockSize => {
                try writer.print("Error: Invalid block size in ext4 filesystem\n", .{});
                return;
            },
            ImageError.ReadError => {
                try writer.print("Error: Failed to read data from image file\n", .{});
                return;
            },
            else => {
                try writer.print("Error processing image: {any}\n", .{err});
                return;
            },
        }
    };

    _ = mounted_image;
}
