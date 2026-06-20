return function(config, helpers)
  local M = {}
  local settings = hs.settings

  local clipboardHistory = settings.get("clipboardHistory") or {}
  local lastClipboardValue = helpers.normalizeText(hs.pasteboard.getContents())
  local watcher = nil

  local function persist()
    settings.set("clipboardHistory", clipboardHistory)
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

    persist()
  end

  function M.items()
    return clipboardHistory
  end

  function M.clear()
    clipboardHistory = {}
    persist()
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
    persist()
  end

  function M.openItemActions(item, index)
    helpers.chooseFromList("Clipboard item", {
      {
        text = "Paste",
        subText = "Paste this item into the front app",
        action = "paste",
      },
      {
        text = "Copy Again",
        subText = "Put this item back on the clipboard",
        action = "copy",
      },
      {
        text = "Delete",
        subText = "Remove this item from clipboard history",
        action = "delete",
      },
    }, function(choice)
      if choice.action == "paste" then
        M.pasteToFrontmostApp(item)
        return
      end

      if choice.action == "copy" then
        M.copyAgain(item)
        return
      end

      if choice.action == "delete" then
        M.deleteAt(index)
        hs.alert.show("Deleted")
      end
    end)
  end

  function M.openChooser()
    local choices = {
      {
        text = "Clear Clipboard History",
        subText = "Remove all saved clipboard items",
        action = "clear",
      },
    }

    for index, item in ipairs(clipboardHistory) do
      table.insert(choices, {
        text = helpers.previewText(item, 80),
        subText = "Clipboard item #" .. index,
        action = "item",
        index = index,
        value = item,
      })
    end

    helpers.chooseFromList("Clipboard history", choices, function(choice)
      if choice.action == "clear" then
        M.clear()
        hs.alert.show("Clipboard history cleared")
        return
      end

      M.openItemActions(choice.value, choice.index)
    end)
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
