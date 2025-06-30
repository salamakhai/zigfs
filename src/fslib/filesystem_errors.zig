pub const FilesystemError = error{
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