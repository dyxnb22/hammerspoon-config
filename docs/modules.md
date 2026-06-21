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

- Open/toggle the launcher webview
- Wrap actions with usage tracking
- Bridge layout save messages to runtime

## launcher_runtime

Responsibilities:

- Build launcher items/actions from module registrations
- Stable layout persistence and usage tracking
- Short-lived cache for window/app snapshots

## webview_panel

Responsibilities:

- Shared webview lifecycle for launcher and notes
- Parse `message.body` from JavaScript callbacks
- Singleton panel instances per channel

## notes_scanner

Responsibilities:

- Recursively scan the configured vault for `.md` files
- Parse front matter, tags, links, and wiki links
- Build `nodes`, `edges`, `tags`, and `recent` index data
- Save index to `~/.hammerspoon/notes-index.json`

## notes

Responsibilities:

- Open markdown files in Typora
- Notes Center webview with graph, browse, search, and recent views
- Daily note creation, index refresh, and vault shortcuts

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
