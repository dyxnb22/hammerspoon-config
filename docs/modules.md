# Modules

## windows

Responsibilities:

- Ordered visible windows
- Recent apps inferred from recent windows
- Window movement helpers
- Window chooser
- App chooser

## clipboard

Responsibilities:

- Clipboard watcher lifecycle
- Clipboard history persistence in `hs.settings`
- Copy again, paste, delete, clear actions

## translate

Responsibilities:

- Pull selected text or clipboard text
- Translate through Google Translate endpoint
- Copy translated result
- Show translation result chooser

## todo

Responsibilities:

- Load and save TODO data
- Keep TODO data in `~/.hammerspoon/todos.json`
- Add, toggle, delete, and copy task text

## launcher

Responsibilities:

- Manage the `hs.webview` window
- Load HTML asset
- Bridge JavaScript actions back to Lua
- Render launcher item state

## config

Responsibilities:

- Repo paths
- Runtime file paths
- Hotkey definitions
- Window layout units

## helpers

Responsibilities:

- Text normalization
- Small file and JSON helpers
- Chooser creation helper
- Selected-text extraction helper
- Safe icon access
