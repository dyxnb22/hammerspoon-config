# Modules

## windows

Responsibilities:

- Ordered visible windows and recent apps
- Installed app catalog (shown when searching)
- Window layout presets (left/right/max/center/screen move)
- `indexContributions()` for launcher search

## clipboard

Responsibilities:

- Clipboard watcher lifecycle
- Clipboard history persistence in `hs.settings`
- Snippets from `config.snippets`
- Paste, copy again, delete, clear via launcher actions

## translate

Responsibilities:

- Translate selection, clipboard, or typed query
- Google Translate endpoint with browser fallback
- Last translation surfaced in launcher (no `hs.dialog`)

## todo

Responsibilities:

- Load and save TODO data in `~/.hammerspoon/todos.json`
- Inline add via launcher search query
- Toggle, delete, and copy via launcher actions

## system

Responsibilities:

- System toggles (DND, Night Shift, dark mode, low power)
- Shell command panel (`! cmd`, `sh cmd`)
- `indexContributions()` for launcher search

## launcher

Responsibilities:

- Open/toggle the unified Spotlight-style webview
- Debounced search bridge to runtime/index layer
- Actions pane with `⌘K` / arrow navigation
- Refresh after in-panel mutations (todo, clipboard, translate)

## launcher_runtime

Responsibilities:

- Orchestrate sync + async index builds
- Layout persistence and usage tracking
- Module hotkey binding passthrough

## search_index

Responsibilities:

- Aggregate `indexContributions()` from all modules
- Rank by prefix match, token hit, usage, and recency
- Calculator, quick links, and async `mdfind` file search

## webview_panel

Responsibilities:

- Shared webview lifecycle for launcher and notes
- Parse `message.body` from JavaScript callbacks
- Primary and secondary actions (`id` + `actionId`, optional `keepOpen`)
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
