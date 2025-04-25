# ZIGFS

A filesystem toolset written in Zig

## Building

To build zigfs:

```bash
# Clone the repository
git clone https://github.com/yourusername/zigfs.git
cd zigfs

# Build using zig
zig build

# Run the executable
./zig-out/bin/zigfs
```

## Basic Usage

```bash
zigfs <command> [arguments]
```

For help with available commands:

```bash
zigfs help
```

For help with a specific command:

```bash
zigfs help <command>
```

## Features

Use `zigfs help` for detailed help on each command.

## How to run globally

### Create a symbolic link (one of solutions)

Link the compiled `zigfs` binary to a directory that is already in `$PATH`, such as `/usr/local/bin`.
Note: Run commands from the project folder

Run build to create binary:
```sh
zig build
```

Ensure the binary is executable:

```sh
chmod +x zig-out/bin/zigfs
```

Create symlink to the binary:

```sh
sudo ln -s "$(pwd)/zig-out/bin/zigfs" /usr/local/bin/zigfs
```

To remove symlink later:

```sh
sudo rm /usr/local/bin/zigfs
```

To verify:

```sh
zigfs
```



## TODOs and notes
- [x] Multithreaded recursive files finder
- [ ] FUSE research
- [ ] mount utilities
- [ ] Multi steps commands, chains 
- [ ] Advanced args, default args
- [ ] Create tests for commands
- [ ] cut command? Files reader
- [ ] loop for interactive (session) mode?
- [ ] Progress indicators for long operations
- [ ] cp/mv/rm
- [ ] Network tools: simple curl (if it can be simple)

Ideas pool:
- [ ] "Friendly" cli. Readble commands chain syntax with user friendly step by step interactions
- [ ] Extender of file's metadata: create tag system for files searching