pub const CoreError = error{
    UnknownCommand,
    ActionFailed,
    InvalidArgument,
    OutOfMemory,
    WriteError,
    EndOfStream,
};
