const Directory = struct {
    name: []const u8,
    files: []File,
    directories: []Directory,
    parent: ?*Directory,
};

const File = struct {
    name: []const u8,
    dir: ?*Directory,
};
