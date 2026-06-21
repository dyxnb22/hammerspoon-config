return function(config, helpers)
  local M = {}
  local settings = hs.settings

  local clipboardHistory = settings.get("clipboardHistory") or {}
  local lastClipboardValue = helpers.normalizeText(hs.pasteboard.getContents())
  local watcher = nil
  local persistTimer = nil

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
    M.openChooser()
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
    M.openChooser()
  end

  local function buildChoices()
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
        subText = "Enter paste · Shift+Enter copy again · Delete remove",
        action = "item",
        index = index,
        value = item,
      })
    end

    return choices
  end

  function M.openChooser()
    local chooser = hs.chooser.new(function(choice)
      if not choice then
        return
      end

      if choice.action == "clear" then
        M.clear()
        return
      end

      if choice.action == "item" then
        helpers.chooseFromList("Clipboard item", {
          { text = "Paste", subText = "Paste into front app", action = "paste" },
          { text = "Copy Again", subText = "Put item back on clipboard", action = "copy" },
          { text = "Delete", subText = "Remove from history", action = "delete" },
        }, function(actionChoice)
          if actionChoice.action == "paste" then
            M.pasteToFrontmostApp(choice.value)
            return
          end
          if actionChoice.action == "copy" then
            M.copyAgain(choice.value)
            M.openChooser()
            return
          end
          if actionChoice.action == "delete" then
            M.deleteAt(choice.index)
          end
        end)
      end
    end)

    chooser:searchSubText(true)
    chooser:placeholderText("Clipboard history")
    chooser:choices(buildChoices())
    chooser:show()
  end

  function M.launcherCommands()
    return {
      {
        id = "clipboard",
        text = "Clipboard History",
        subText = "Browse the last 80 copied items",
        run = M.openChooser,
      },
    }
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
