return function(config, helpers)
  local scanner = nil
  local panel = nil
  local currentIndex = nil
  local indexLoadedAt = 0
  local homeHandler = nil
  local launcherToggle = nil

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
    hs.hotkey.bind(hotkeys.recent.modifiers, hotkeys.recent.key, function()
      if launcherToggle then
        launcherToggle("note")
      else
        M.open({ toggle = true })
      end
    end)
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

  function M.setLauncherWithQueryHandler(fn)
    launcherToggle = fn
  end

  function M.indexContributions(query)
    local items = {}
    local handlers = {}
    -- Use in-memory cache; only read from disk if not yet loaded
    local index = currentIndex
    if not index then
      index = helpers.readJsonFile(config.notes.indexFile, { recent = {}, nodes = {} })
      if index and (index.nodes or index.recent) then
        currentIndex = index
        indexLoadedAt = os.time()
      end
    end

    if helpers.matchQuery(query, "notes", "note", "vault", "typora", "markdown") then
      local centerId = "notes:center"
      table.insert(items, {
        id = centerId,
        kind = "command",
        title = "Notes Center",
        subtitle = "Browse vault, graph, and search",
        badge = "Notes",
        accent = helpers.accentForId(centerId),
        keywords = "notes vault typora markdown",
        actions = {
          { id = "open", label = "Open", primary = true },
        },
      })
      handlers[centerId] = function()
        M.open({ toggle = false })
      end
      handlers[centerId .. ":open"] = handlers[centerId]
    end

    if helpers.matchQuery(query, "notes", "note", "daily", "journal", "today", "笔记", "日记") then
      local dailyId = "notes:daily"
      table.insert(items, {
        id = dailyId,
        kind = "command",
        title = "New Daily Note",
        subtitle = "Create or open today's journal",
        badge = "Notes",
        accent = helpers.accentForId(dailyId),
        keywords = "daily journal note today 日记 笔记",
        actions = {
          { id = "open", label = "Open", primary = true },
        },
      })
      handlers[dailyId] = function()
        local path = M.newDailyNote()
        M.openInTypora(path)
      end
      handlers[dailyId .. ":open"] = handlers[dailyId]
    end

    for _, item in ipairs(index.recent or {}) do
      local tagsText = ""
      if type(item.tags) == "table" then
        tagsText = table.concat(item.tags, " ")
      end
      if helpers.matchQuery(query, item.title, item.path, tagsText) then
        local id = "note:" .. helpers.hashString(item.path)
        table.insert(items, {
          id = id,
          kind = "note",
          title = item.title,
          subtitle = item.path,
          badge = "Note",
          accent = helpers.accentForId(id),
          keywords = table.concat({ item.title, item.path, tagsText }, " "),
          actions = {
            { id = "open", label = "Open in Typora", primary = true },
            { id = "reveal", label = "Reveal in Finder" },
          },
        })
        handlers[id] = function()
          M.openInTypora(item.path)
        end
        handlers[id .. ":open"] = handlers[id]
        handlers[id .. ":reveal"] = function()
          hs.execute("open -R " .. shellQuote(item.path))
        end
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  return M
end
