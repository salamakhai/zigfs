const std = @import("std");

pub const Error = error{
    DirectoryChangeFailed,
    AccessDenied,
    FileNotFound,
    NotDir,
};
