pub const FileSystemError = error{
    UnsupportedFormat,
    InvalidFileSystem,
    ReadError,
    EntryNotFound,
    NotDirectory,
    NotFile,
    InvalidNode,
    OutOfBounds,
    InvalidMagicNumber,
    NotExt4Format,
    InvalidBlockSize,
};