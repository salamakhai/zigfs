# CLI - Command Line Interface
[_readme backlink_](../../README.md)

## Core
Provides unified interface for CLI components, holds shared types and utilities

## Architecture
### Structure

#### `/core/`
Shared types and utilities for CLI components

#### `/context/`
State management and filesystem session handling

#### `/commands/`
High-level command interface and argument parsing

#### `/actions/`
Core operations on context

#### `root.zig`
Module exports and public CLI interface