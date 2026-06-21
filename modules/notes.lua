return function(config, helpers)
  local scanner = nil
  local panel = nil
  local currentIndex = nil
  local indexLoadedAt = 0
  local homeHandler = nil

  local M = {}

  local function getScanner()
    if not scanner then
      scanner = require("notes_scanner")(config, helpers)
    end
    return scanner
  end

  local function getPanel()
    if not panel then
      local webviewPanel = require("webview_panel")(config, helpers)
      panel = webviewPanel.create({
        channel = "notes",
        htmlPath = config.assetsDir .. "/notes.html",
        frame = function()
          local screen = hs.screen.mainScreen():frame()
          local width = math.min(1180, screen.w - 40)
          local height = math.min(820, screen.h - 40)

          return {
            x = screen.x + math.floor((screen.w - width) / 2),
            y = screen.y + math.floor((screen.h - height) / 2),
            w = width,
            h = height,
          }
        end,
        onMessage = function(payload, hidePanel)
          if payload.type == "home" then
            hidePanel()
            if homeHandler then
              hs.timer.doAfter(0.08, homeHandler)
            end
            return
          end

          if payload.type == "open" and payload.path then
            hidePanel()
            hs.timer.doAfter(0.08, function()
              M.openInTypora(payload.path)
            end)
            return
          end

          if payload.type == "refresh" then
            currentIndex = M.refreshIndex(true)
            panel.evaluate("window.setNotesIndex(" .. hs.json.encode(currentIndex) .. ");")
            hs.alert.show("Notes index refreshed")
            return
          end

          if payload.type == "newDaily" then
            hidePanel()
            hs.timer.doAfter(0.08, function()
              local path = M.newDailyNote()
              M.openInTypora(path)
            end)
          end
        end,
      })
    end

    return panel
  end

  local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
  end

  function M.openInTypora(filePath)
    if not filePath or filePath == "" then
      hs.alert.show("No note path")
      return false
    end

    local attr = hs.fs.attributes(filePath)
    if not attr then
      local dir = filePath:match("^(.*)/[^/]+$")
      if dir then
        helpers.ensureDir(dir)
      end
      local file = io.open(filePath, "w")
      if file then
        local title = filePath:match("([^/]+)%.md$") or "Untitled"
        file:write("# " .. title:gsub("%.md$", "") .. "\n\n")
        file:close()
      end
    end

    local appName = shellQuote(config.notes.typoraApp)
    local quotedPath = shellQuote(filePath)
    hs.execute("open -a " .. appName .. " " .. quotedPath)
    return true
  end

  function M.openVaultInFinder()
    helpers.ensureDir(config.notes.vaultPath)
    hs.execute("open " .. shellQuote(config.notes.vaultPath))
  end

  function M.newDailyNote()
    local dailyDir = config.notes.vaultPath .. "/" .. config.notes.dailyDir
    helpers.ensureDir(dailyDir)

    local stamp = os.date("%Y-%m-%d")
    local path = dailyDir .. "/" .. stamp .. ".md"
    local created = false

    if not hs.fs.attributes(path) then
      local file = io.open(path, "w")
      if file then
        file:write("# " .. stamp .. "\n\n")
        file:close()
        created = true
      end
    end

    if created then
      M.refreshIndex(true)
    end

    return path
  end

  function M.refreshIndex(force)
    if force or not currentIndex then
      currentIndex = getScanner().refresh()
      indexLoadedAt = os.time()
    end
    return currentIndex
  end

  function M.seedWelcomeVault()
    local root = config.notes.vaultPath
    helpers.ensureDir(root)
    helpers.ensureDir(root .. "/" .. config.notes.dailyDir)

    local welcomePath = root .. "/Welcome.md"
    if not hs.fs.attributes(welcomePath) then
      local file = io.open(welcomePath, "w")
      if file then
        file:write([=[---
tags: [notes, welcome]
---

# Welcome

This vault is managed by Hammerspoon Notes Center.

- Edit notes in Typora
- Link notes with [[Getting Started]]
- Press Ctrl+Alt+Cmd+I to refresh the index

]=])
        file:close()
      end
    end

    local guidePath = root .. "/Getting Started.md"
    if not hs.fs.attributes(guidePath) then
      local file = io.open(guidePath, "w")
      if file then
        file:write([[---
parent: Welcome
tags: [guide]
links: [Welcome]
---

# Getting Started

Use the graph view to explore note links, or search by title and tags.

]])
        file:close()
      end
    end
  end

  function M.loadIndex(force)
    if not force and currentIndex and indexLoadedAt > 0 then
      return currentIndex
    end

    currentIndex = getScanner().loadIndex()
    indexLoadedAt = os.time()

    if not currentIndex.nodes or #currentIndex.nodes == 0 then
      M.seedWelcomeVault()
      currentIndex = M.refreshIndex(true)
    end

    return currentIndex
  end

  function M.openRecentChooser()
    local index = M.loadIndex(false)
    local choices = {}

    for _, item in ipairs(index.recent or {}) do
      table.insert(choices, {
        text = item.title,
        subText = item.path,
        path = item.path,
      })
      if #choices >= 30 then
        break
      end
    end

    if #choices == 0 then
      hs.alert.show("No notes found in vault")
      return
    end

    helpers.chooseFromList("Recent notes", choices, function(choice)
      M.openInTypora(choice.path)
    end)
  end

  function M.open(options)
    options = options or {}
    currentIndex = M.loadIndex(false)

    local method = options.toggle and "toggle" or "show"
    getPanel()[method]({
      eval = "window.setNotesIndex(" .. hs.json.encode(currentIndex) .. "); window.focusNotes();",
    })
  end

  function M.bindHotkeys()
    local hotkeys = config.notes.hotkeys

    hs.hotkey.bind(hotkeys.center.modifiers, hotkeys.center.key, function()
      M.open({ toggle = true })
    end)
    hs.hotkey.bind(hotkeys.recent.modifiers, hotkeys.recent.key, M.openRecentChooser)
    hs.hotkey.bind(hotkeys.newDaily.modifiers, hotkeys.newDaily.key, function()
      local path = M.newDailyNote()
      M.openInTypora(path)
    end)
    hs.hotkey.bind(hotkeys.refresh.modifiers, hotkeys.refresh.key, function()
      M.refreshIndex(true)
      hs.alert.show("Notes index refreshed")
    end)
    hs.hotkey.bind(hotkeys.openVault.modifiers, hotkeys.openVault.key, M.openVaultInFinder)
  end

  function M.setHomeHandler(handler)
    homeHandler = handler
  end

  function M.launcherCommands()
    return {
      {
        id = "notes",
        text = "Notes Center",
        subText = "Browse vault, graph links, and open in Typora",
        run = function()
          M.open({ toggle = false })
        end,
      },
      {
        id = "notes-recent",
        text = "Recent Notes",
        subText = "Open a recently edited markdown note",
        run = M.openRecentChooser,
      },
      {
        id = "notes-daily",
        text = "New Daily Note",
        subText = "Create or open today's journal note",
        run = function()
          local path = M.newDailyNote()
          M.openInTypora(path)
        end,
      },
    }
  end

  return M
end
