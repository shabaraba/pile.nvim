# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview
pile.nvim is a Neovim plugin that provides a vertical buffer sidebar for managing open buffers, similar to how books are stacked in a pile. It's designed to offer an intuitive and simple buffer management experience.

## Architecture
The plugin follows a modular architecture:

- **Core Module** (`lua/pile/init.lua`): Entry point that provides setup and command registration
- **Config Module** (`lua/pile/config.lua`): Centralized configuration management with defaults
- **Buffers Module** (`lua/pile/buffers/`): Buffer management, filtering, and duplicate file path handling
- **Windows Module** (`lua/pile/windows/`): Window management including sidebar and popup components
- **Logging Module** (`lua/pile/log.lua`): Debug logging system with configurable levels

## Key Implementation Details

### Buffer Filtering Logic
The buffer list filters out:
- Buffers without names
- Popup, notify, and nofile buffer types
- oil.nvim temporary buffers (oil:// protocol and oil filetype)
- Only displays buffers that are either currently displayed in a window OR have file extensions

### Duplicate File Handling
When multiple files with the same name exist, the plugin intelligently displays minimal distinguishing path information by:
1. Finding unique path segments among duplicates
2. Preferring higher-level (closer to root) unique segments
3. Falling back to parent directory display when no unique segments exist

### Event-Driven Updates
The sidebar automatically updates on:
- BufAdd, BufLeave, BufEnter events
- FileType changes (with special handling for oil.nvim integration)

## Commands
No build or test commands are currently defined for this plugin. The plugin is loaded directly by Neovim's plugin manager.

## Development Guidelines
- Use the debug logging system (`require('pile.log')`) for troubleshooting
- Enable debug mode via setup options: `{ debug = { enabled = true, level = "debug" } }`
- Maintain compatibility with oil.nvim for file browser integration
- Required dependency: nui.nvim for UI components