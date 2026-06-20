# Architecture

## Intent

This repo is designed for long-term personal maintenance with AI-assisted development.

The architecture favors:

- Small Lua modules
- A thin bootstrap path
- UI assets separated from business logic
- Simple feature toggles
- Easy iteration in Cursor

## Loading Model

1. Hammerspoon starts from `~/.hammerspoon/init.lua`
2. The bootstrap updates `package.path`
3. The bootstrap loads `/Users/diaoyuxuan/hammerspoon-config/init.lua`
4. Repo `init.lua` reads `modules/modules_enabled.lua`
5. Enabled modules are instantiated
6. Commands and hotkeys are registered from enabled modules

## Design Rules

- `init.lua` should orchestrate, not contain large feature logic
- Each module should own one clear responsibility
- Shared helpers belong in `modules/helpers.lua`
- Paths, hotkeys, and frame constants belong in `modules/config.lua`
- Launcher UI structure belongs in `assets/launcher.html`
- Notes Center UI structure belongs in `assets/notes.html`
- Shared webview lifecycle belongs in `modules/webview_panel.lua`
- Personal state should not be committed

## Why Webview For Launcher And Notes

The launcher and notes center use `hs.webview` instead of `hs.chooser` because:

- It allows a more polished macOS/iOS-style UI
- It keeps layout and styling editable as frontend-like assets
- It makes future UI extensions much easier
- JavaScript can post messages back to Lua through `message.body`

## Change Strategy

When adding new features:

1. Decide whether the feature is a new module or an extension of an existing one
2. Add a toggle in `modules/modules_enabled.lua` if it is a standalone module
3. Keep launcher wiring inside repo `init.lua`
4. Keep rendering changes inside `assets/launcher.html` unless there is a strong reason not to
