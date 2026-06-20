# Hammerspoon Requirements

## Product Direction

Build a maintainable personal macOS launcher and automation workspace with Hammerspoon.

## Architecture Rules

- Keep source code in `/Users/diaoyuxuan/hammerspoon-config`
- Keep personal runtime state in `~/.hammerspoon`
- Split behavior by modules instead of one large `init.lua`
- Keep the custom launcher UI in a standalone asset file
- Support module toggles so features can be enabled or disabled cleanly

## Current Features

### Launcher

- Entry hotkey: `Cmd + Shift + Space`
- Show recent windows first
- Show recent apps second
- Show commands after that
- Use a card-based macOS/iOS-style floating UI
- Support keyboard search, arrows, Enter, and Escape

### Clipboard

- Keep the last 80 meaningful clipboard items
- Support paste, copy again, delete, and clear all

### Translation

- Prefer selected text
- Fall back to clipboard text
- Auto-detect whether to translate to Chinese or English
- Copy translated result automatically

### TODO

- Save todos locally
- Support add, toggle, copy, delete
- Sort undone items above done items

### Window Management

- Left, right, top, bottom, maximize, center
- Window switcher
- App switcher based on recent active windows

### Notes

- Scan a configurable Typora vault directory
- Build a local `notes-index.json` with nodes, edges, tags, and recent files
- Notes Center webview with link graph, hierarchy, tag clusters, browse, search, and recent views
- Open notes in Typora from graph nodes, lists, and search results
- Daily note shortcut and vault refresh shortcuts

## Maintenance Standards

- Prefer small modules with clear boundaries
- Keep machine-specific paths isolated in `modules/config.lua`
- Keep UI assets editable by frontend tools
- Make behavior easy for Cursor to change without touching unrelated modules
