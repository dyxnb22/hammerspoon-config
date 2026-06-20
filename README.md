# Hammerspoon Config

Personal Hammerspoon workspace for macOS productivity, launcher UX, and developer automation.

## What This Repo Owns

- The Hammerspoon source code
- The custom launcher UI
- Project documentation and Cursor rules
- Module boundaries and feature toggles

This repo does not store personal runtime state such as local TODO data. That stays in `~/.hammerspoon/`.

## Repo Location

- Source repo: `/Users/diaoyuxuan/hammerspoon-config`
- Hammerspoon bootstrap: `~/.hammerspoon/init.lua`

The bootstrap file is intentionally thin. It only points Hammerspoon at this repo.

## Architecture

- `init.lua`
  Repo entry point. Loads modules, toggles, commands, and hotkeys.
- `modules/config.lua`
  Central place for machine-specific paths, hotkeys, and layout constants.
- `modules/modules_enabled.lua`
  Feature toggle file. Turn modules on or off here.
- `modules/*.lua`
  One module per concern.
- `assets/launcher.html`
  Launcher UI shell for the card-style webview.
- `docs/`
  Product notes, constraints, architecture, and maintenance guidance.
- `.cursor/rules/`
  Cursor project rules for implementation behavior.

## Runtime State

These files stay outside Git on purpose:

- `~/.hammerspoon/init.lua`
- `~/.hammerspoon/todos.json`
- `~/.hammerspoon/notes-index.json`

## Current Modules

- `windows`
  Window movement, window switcher, recent-app switcher
- `clipboard`
  Clipboard history watcher and actions
- `translate`
  Google Translate integration
- `todo`
  Local TODO capture and management
- `launcher`
  Card-style launcher UI and action bridge
- `notes`
  Typora vault scanner, notes center webview, graph and search

## Hotkeys

- `Cmd + Shift + Space`
  Open the launcher
- `Ctrl + Alt + Cmd + R`
  Reload Hammerspoon config
- `Ctrl + Alt + Cmd + W`
  Open window switcher
- `Ctrl + Alt + Cmd + A`
  Open app switcher
- `Ctrl + Alt + Cmd + V`
  Open clipboard history
- `Ctrl + Alt + Cmd + T`
  Open TODO manager
- `Ctrl + Alt + Cmd + G`
  Open translation prompt
- `Ctrl + Alt + Cmd + N`
  Open notes center
- `Ctrl + Alt + Cmd + Shift + N`
  Open recent notes
- `Ctrl + Alt + Cmd + D`
  Create or open today's daily note
- `Ctrl + Alt + Cmd + I`
  Refresh notes index
- `Ctrl + Alt + Cmd + O`
  Open notes vault in Finder
- `Ctrl + Alt + Cmd + H/L/K/J`
  Tile left/right/top/bottom
- `Ctrl + Alt + Cmd + F`
  Maximize window
- `Ctrl + Alt + Cmd + C`
  Center focused window

## Module Toggles

Edit [modules_enabled.lua](/Users/diaoyuxuan/hammerspoon-config/modules/modules_enabled.lua).

Example:

```lua
return {
  windows = true,
  clipboard = true,
  translate = false,
  todo = true,
  notes = true,
}
```

Setting a module to `false` disables:

- Module loading
- Related launcher commands
- Related hotkeys

## Cursor Workflow

Open the repo root in Cursor:

- `/Users/diaoyuxuan/hammerspoon-config`

Important project rules live in:

- [.cursor/rules/00-project.mdc](/Users/diaoyuxuan/hammerspoon-config/.cursor/rules/00-project.mdc)
- [.cursor/rules/10-cursor-ai-mode.mdc](/Users/diaoyuxuan/hammerspoon-config/.cursor/rules/10-cursor-ai-mode.mdc)
- [.cursor/rules/20-hammerspoon-implementation.mdc](/Users/diaoyuxuan/hammerspoon-config/.cursor/rules/20-hammerspoon-implementation.mdc)

## Development Loop

1. Edit code or UI in Cursor
2. Reload Hammerspoon with `Ctrl + Alt + Cmd + R`
3. Verify launcher and hotkeys manually
4. Commit in this repo

## Docs

- [requirements.md](/Users/diaoyuxuan/hammerspoon-config/docs/requirements.md)
- [architecture.md](/Users/diaoyuxuan/hammerspoon-config/docs/architecture.md)
- [constraints.md](/Users/diaoyuxuan/hammerspoon-config/docs/constraints.md)
- [modules.md](/Users/diaoyuxuan/hammerspoon-config/docs/modules.md)

## Next Good Extensions

- Project launcher cards
- Repo-aware actions
- Snippet runner
- Better app icons and metadata in launcher cards
- Search ranking tuned for active development workflows
- Backlinks panel and richer graph layouts in notes center

## Notes Vault Setup

Edit `modules/config.lua` and set `notes.vaultPath` to your Typora vault directory.

On first open, Notes Center creates a starter vault with sample linked notes if the directory is empty.
