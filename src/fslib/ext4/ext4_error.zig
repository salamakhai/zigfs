pub const Ext4Error = error{
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
