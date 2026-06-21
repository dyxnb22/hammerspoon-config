return function(config, helpers)
  local M = {}
  local settings = hs.settings

  local clipboardHistory = settings.get("clipboardHistory") or {}
  local lastClipboardValue = helpers.normalizeText(hs.pasteboard.getContents())
  local watcher = nil
  local persistTimer = nil
  local refreshLauncher = nil

  local function persist()
    settings.set("clipboardHistory", clipboardHistory)
    persistTimer = nil
  end

  local function schedulePersist()
    if persistTimer then
      persistTimer:stop()
    end
    persistTimer = hs.timer.doAfter(0.3, persist)
  end

  function M.setRefreshHandler(fn)
    refreshLauncher = fn
  end

  function M.push(text)
    local normalized = helpers.normalizeText(text)
    if not normalized then
      return
    end

    if clipboardHistory[1] == normalized then
      return
    end

    for index = #clipboardHistory, 1, -1 do
      if clipboardHistory[index] == normalized then
        table.remove(clipboardHistory, index)
      end
    end

    table.insert(clipboardHistory, 1, normalized)

    while #clipboardHistory > config.clipboardLimit do
      table.remove(clipboardHistory)
    end

    schedulePersist()
  end

  function M.items()
    return clipboardHistory
  end

  function M.clear()
    clipboardHistory = {}
    schedulePersist()
    hs.alert.show("Clipboard history cleared")
    if refreshLauncher then
      refreshLauncher()
    end
  end

  function M.copyAgain(text)
    hs.pasteboard.setContents(text)
    hs.alert.show("Copied")
  end

  function M.pasteToFrontmostApp(text)
    local targetApp = hs.application.frontmostApplication()
    hs.pasteboard.setContents(text)
    if targetApp then
      targetApp:activate()
      hs.timer.doAfter(0.12, function()
        hs.eventtap.keyStroke({ "cmd" }, "v")
      end)
    end
  end

  function M.deleteAt(index)
    table.remove(clipboardHistory, index)
    schedulePersist()
    hs.alert.show("Deleted")
    if refreshLauncher then
      refreshLauncher()
    end
  end

  function M.indexContributions(query)
    local items = {}
    local handlers = {}
    local normalizedQuery = helpers.normalizeText(query)
    local clipboardMode = helpers.matchQuery(query, "clipboard", "history", "paste", "copy")

    if clipboardMode then
      local clearId = "clipboard:clear"
      table.insert(items, {
        id = clearId,
        kind = "command",
        title = "Clear Clipboard History",
        subtitle = "Remove all saved clipboard items",
        badge = "Clipboard",
        accent = helpers.accentForId(clearId),
        keywords = "clipboard history clear paste copy",
        actions = {
          { id = "open", label = "Clear All", primary = true },
        },
      })
      handlers[clearId] = M.clear
      handlers[clearId .. ":open"] = M.clear
    end

    local maxVisible = normalizedQuery and #clipboardHistory or math.min(12, #clipboardHistory)
    for index = 1, maxVisible do
      local text = clipboardHistory[index]
      local preview = helpers.previewText(text, 80)
      -- In clipboard mode (paste/copy/clipboard/history query) show all items;
      -- otherwise filter by content match.
      local matchesClipboardItem = not normalizedQuery
        or clipboardMode
        or (#normalizedQuery >= 3 and helpers.matchQuery(query, preview))

      if matchesClipboardItem then
        local id = "clipboard:" .. index
        table.insert(items, {
          id = id,
          kind = "clipboard",
          title = preview,
          subtitle = "Clipboard history",
          badge = "Clipboard",
          accent = helpers.accentForId(id),
          keywords = text .. " clipboard paste copy history",
          actions = {
            { id = "paste", label = "Paste", primary = true },
            { id = "copy", label = "Copy Again" },
            { id = "delete", label = "Delete" },
          },
        })
        handlers[id] = function()
          M.pasteToFrontmostApp(text)
        end
        handlers[id .. ":paste"] = handlers[id]
        handlers[id .. ":copy"] = function()
          M.copyAgain(text)
        end
        handlers[id .. ":delete"] = function()
          M.deleteAt(index)
        end
      end
    end

    for _, snippet in ipairs(config.snippets or {}) do
      if helpers.matchQuery(query, snippet.title, snippet.text, snippet.keywords) then
        local id = "snippet:" .. helpers.hashString(snippet.title)
        table.insert(items, {
          id = id,
          kind = "snippet",
          title = snippet.title,
          subtitle = helpers.previewText(snippet.text, 60),
          badge = "Snippet",
          accent = helpers.accentForId(id),
          keywords = table.concat({ snippet.title, snippet.text, snippet.keywords }, " "),
          actions = {
            { id = "paste", label = "Paste", primary = true },
            { id = "copy", label = "Copy" },
          },
        })
        handlers[id] = function()
          M.pasteToFrontmostApp(snippet.text)
        end
        handlers[id .. ":paste"] = handlers[id]
        handlers[id .. ":copy"] = function()
          M.copyAgain(snippet.text)
        end
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  function M.start()
    if lastClipboardValue then
      M.push(lastClipboardValue)
    end

    watcher = hs.pasteboard.watcher.new(function()
      local current = helpers.normalizeText(hs.pasteboard.getContents())
      if current and current ~= lastClipboardValue then
        lastClipboardValue = current
        M.push(current)
      end
    end)
    watcher:start()
  end

  return M
end
