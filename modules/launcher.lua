return function(config, helpers)
  local webviewPanel = require("webview_panel")(config, helpers)
  local runtime = require("launcher_runtime")(config, helpers)

  local M = {}
  local currentQuery = ""

  local function stringsPayload()
    return {
      title = "Spotlight",
      subtitle = "Search apps, files, commands, clipboard, and more",
      searchPlaceholder = "Search or type a command...",
      edit = "Edit",
      done = "Done",
      all = "All",
      window = "Windows",
      app = "Apps",
      command = "Commands",
      clipboard = "Clipboard",
      todo = "Tasks",
      file = "Files",
      ai = "AI",
      system = "System",
      empty = "No matches yet. Try another keyword.",
      loading = "Searching...",
      hint = "Enter run | Tab filter | Cmd+K actions | Esc close",
      results = "results",
      actions = "Actions",
      actionHint = "Choose an action",
    }
  end

  local function encodeState(items, loading, query)
    return hs.json.encode({
      items = items,
      layout = runtime.layoutOrder(),
      strings = stringsPayload(),
      loading = loading == true,
      query = query or "",
    })
  end

  local function wrapHandlers(handlers, items)
    local wrapped = {}
    local itemIds = {}

    for _, item in ipairs(items or {}) do
      itemIds[item.id] = true
    end

    local function usageIdForKey(key)
      if itemIds[key] then
        return key
      end

      local bestMatch = nil
      for itemId in pairs(itemIds) do
        if key:sub(1, #itemId + 1) == itemId .. ":" then
          if not bestMatch or #itemId > #bestMatch then
            bestMatch = itemId
          end
        end
      end

      return bestMatch or key
    end

    for key, action in pairs(handlers or {}) do
      wrapped[key] = function()
        runtime.recordUsage(usageIdForKey(key))
        action()
      end
    end
    return wrapped
  end

  function M.pushState(query, visibleOnly)
    currentQuery = query or ""

    if visibleOnly then
      local hsWindow = panel and panel.view and panel.view:hswindow()
      if not hsWindow or not hsWindow:isVisible() then
        return
      end
    end

    local ok, err = pcall(function()
      runtime.buildState(currentQuery, function(state)
        if panel then
          panel.setActions(wrapHandlers(state.handlers or {}, state.items))
          panel.evaluate("window.setLauncherState(" .. encodeState(state.items, state.loading, state.query) .. ");")
        end
      end)
    end)

    if not ok then
      hs.printf("launcher pushState error: %s", tostring(err))
      hs.alert.show("Launcher search failed")
    end
  end

  function M.refresh()
    M.pushState(currentQuery, true)
  end

  local panel = webviewPanel.create({
    channel = "launcher",
    htmlPath = config.assetsDir .. "/launcher.html",
    frame = function()
      local screen = hs.screen.mainScreen():frame()
      local width = math.min(920, screen.w - 48)
      local height = math.min(720, screen.h - 48)

      return {
        x = screen.x + math.floor((screen.w - width) / 2),
        y = screen.y + math.floor((screen.h - height) / 2),
        w = width,
        h = height,
      }
    end,
    onMessage = function(payload)
      if payload.type == "saveLayout" and payload.order then
        runtime.saveLayout(payload.order)
        return
      end

      if payload.type == "search" then
        M.pushState(payload.query or "", true)
      end
    end,
  })

  function M.toggle()
    local ok, err = pcall(function()
      local hsWindow = panel.view and panel.view:hswindow()
      if hsWindow and hsWindow:isVisible() then
        panel.hide()
        return
      end

      currentQuery = ""
      panel.show({
        actions = {},
        eval = "window.setLauncherState({items:[],loading:true,strings:" .. hs.json.encode(stringsPayload()) .. ",query:\"\"}); window.focusLauncher();",
      })

      -- Single buildState call: sync results arrive first (no loading flash for empty query),
      -- then async file results merge in if the query is long enough
      runtime.buildState("", function(state)
        panel.setActions(wrapHandlers(state.handlers or {}, state.items))
        panel.evaluate("window.setLauncherState(" .. encodeState(state.items, state.loading, state.query) .. ");")
      end)
    end)

    if not ok then
      hs.alert.show("Launcher failed to open")
      hs.printf("launcher toggle error: %s", tostring(err))
    end
  end

  function M.toggleWithQuery(query)
    local ok, err = pcall(function()
      local hsWindow = panel.view and panel.view:hswindow()
      if hsWindow and hsWindow:isVisible() then
        panel.evaluate("window.overrideQuery(" .. hs.json.encode(query or "") .. ");")
        currentQuery = query or ""
        runtime.buildState(currentQuery, function(state)
          panel.setActions(wrapHandlers(state.handlers or {}, state.items))
          panel.evaluate("window.setLauncherState(" .. encodeState(state.items, state.loading, state.query) .. ");")
        end)
        return
      end

      currentQuery = query or ""
      panel.show({
        actions = {},
        eval = "window.setLauncherState({items:[],loading:true,strings:" .. hs.json.encode(stringsPayload()) .. ",query:\"\"}); window.focusLauncher();",
      })

      runtime.buildState(currentQuery, function(state)
        panel.setActions(wrapHandlers(state.handlers or {}, state.items))
        panel.evaluate("window.setLauncherState(" .. encodeState(state.items, state.loading, state.query) .. "); window.overrideQuery(" .. hs.json.encode(currentQuery) .. "); window.focusLauncher();")
      end)
    end)

    if not ok then
      hs.alert.show("Launcher failed to open")
      hs.printf("launcher toggleWithQuery error: %s", tostring(err))
    end
  end

  function M.registerRuntime(moduleMap)
    runtime.registerModules(moduleMap)

    for _, moduleInstance in pairs(moduleMap or {}) do
      if moduleInstance and moduleInstance.setRefreshHandler then
        moduleInstance.setRefreshHandler(M.refresh)
      end
      if moduleInstance and moduleInstance.setLauncherWithQueryHandler then
        moduleInstance.setLauncherWithQueryHandler(M.toggleWithQuery)
      end
    end
  end

  function M.bindModuleHotkeys()
    runtime.bindModuleHotkeys()
  end

  function M.menubarStatus()
    return runtime.menubarStatus()
  end

  return M
end
