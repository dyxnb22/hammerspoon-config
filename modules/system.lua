return function(config, helpers)
  local M = {}

  local function runShortcut(name)
    local _, ok = hs.execute(string.format("shortcuts run %q 2>/dev/null", name))
    return ok
  end

  local toggles = {
    {
      id = "dnd",
      title = "Toggle Do Not Disturb",
      subtitle = "Focus mode via Shortcuts",
      keywords = "dnd focus disturb",
      run = function()
        if runShortcut("Set Focus") then
          hs.alert.show("Triggered Focus shortcut")
          return
        end
        hs.eventtap.keyStroke({ "ctrl", "cmd" }, "d")
      end,
    },
    {
      id = "nightshift",
      title = "Toggle Night Shift",
      subtitle = "Display warmth",
      keywords = "night shift display",
      run = function()
        if runShortcut("Night Shift") then
          hs.alert.show("Triggered Night Shift shortcut")
          return
        end
        hs.alert.show("Install a Night Shift shortcut or use Control Center")
      end,
    },
    {
      id = "darkmode",
      title = "Toggle Dark Mode",
      subtitle = "System appearance",
      keywords = "dark mode appearance theme",
      run = function()
        hs.execute([[osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode']])
      end,
    },
    {
      id = "lowpower",
      title = "Toggle Low Power Mode",
      subtitle = "Battery saver",
      keywords = "low power battery",
      run = function()
        local output = hs.execute("pmset -g custom")
        local enabled = output and output:find("lowpowermode%s+1", 1, false) ~= nil
        local _, ok = hs.execute("pmset -a lowpowermode " .. (enabled and "0" or "1"))
        hs.alert.show(ok and "Toggled low power mode" or "Failed to toggle low power mode")
      end,
    },
  }

  function M.indexContributions(query)
    local items = {}
    local handlers = {}

    for _, toggle in ipairs(toggles) do
      if helpers.matchQuery(query, toggle.title, toggle.subtitle, toggle.keywords, "system toggle") then
        local id = "system:" .. toggle.id
        table.insert(items, {
          id = id,
          kind = "system",
          title = toggle.title,
          subtitle = toggle.subtitle,
          badge = "System",
          accent = helpers.accentForId(id),
          keywords = toggle.keywords,
          actions = {
            { id = "open", label = "Toggle", primary = true },
          },
        })
        handlers[id] = toggle.run
        handlers[id .. ":open"] = toggle.run
      end
    end

    local command = nil
    if query and query:match("^%s*!%s+") then
      command = query:match("^%s*!%s+(.+)$")
    elseif query and query:match("^%s*sh%s+") then
      command = query:match("^%s*sh%s+(.+)$")
    elseif query and query:match("^%s*shell%s+") then
      command = query:match("^%s*shell%s+(.+)$")
    end

    if command and #command > 0 then
        local id = "shell:" .. helpers.hashString(command)
        table.insert(items, {
          id = id,
          kind = "shell",
          title = "Run: " .. helpers.previewText(command, 56),
          subtitle = "Shell command",
          badge = "Shell",
          accent = helpers.accentForId(id),
          keywords = (query or "") .. " " .. command,
          actions = {
            { id = "open", label = "Run", primary = true },
            { id = "copy", label = "Copy Command" },
          },
        })
        handlers[id] = function()
          local output, ok = hs.execute(command)
          if ok then
            hs.alert.show(helpers.previewText(output or "Done", 80))
          else
            hs.alert.show("Command failed")
          end
        end
        handlers[id .. ":open"] = handlers[id]
        handlers[id .. ":copy"] = function()
          hs.pasteboard.setContents(command)
          hs.alert.show("Copied command")
        end
    end

    if helpers.matchQuery(query, "shell", "terminal", "command", "!") and not command then
      local id = "shell:hint"
      table.insert(items, {
        id = id,
        kind = "shell",
        title = "Run shell command",
        subtitle = "Type ! command or sh command",
        badge = "Shell",
        accent = helpers.accentForId(id),
        keywords = "shell sh terminal",
        actions = {
          { id = "open", label = "Info", primary = true },
        },
      })
      handlers[id] = function()
        hs.alert.show("Prefix with ! or sh to run a command")
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  return M
end
