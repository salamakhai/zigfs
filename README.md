# zigfs

`zigfs` is a colletion of simple zig CLI tools.

## Features

- `ls [directory]` — List directory contents  
- `find pattern [path]` — Find files matching a pattern  

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

To remove the symlink later:

```sh
sudo rm /usr/local/bin/zigfs
```

To verify:

```sh
zigfs
```



# TODOs
- [x] Multithreaded recursive files finder
- [ ] Multi steps commands, complex chains 
- [ ] Advanced args, default args
- [ ] Create tests for commands
- [ ] Progress indicators for long operations
- [ ] cp/mv/rm
- [ ] Network tools: simple curl (if it can be simple)

Ideas pool:
- [ ] "Friendly" cli. Readble commands chain syntax with user friendly step by step interactions
- [ ] Extender of file's metadata: create tag system for files searching