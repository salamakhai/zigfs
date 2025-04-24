pub const CliError = error{
    UnknownCommand,
    CommandFailed,
    InvalidArgument,
    OutOfMemory,
};
