return function(config, helpers)
  local webviewPanel = require("webview_panel")(config, helpers)
  local runtime = require("launcher_runtime")(config, helpers)

  local panel = webviewPanel.create({
    channel = "launcher",
    htmlPath = config.assetsDir .. "/launcher.html",
    frame = function()
      local screen = hs.screen.mainScreen():frame()
      local width = math.min(720, screen.w - 48)
      local height = math.min(760, screen.h - 48)

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
      end
    end,
  })

  local M = {}

  local function wrapActions(actions)
    local wrapped = {}

    for id, action in pairs(actions or {}) do
      wrapped[id] = function()
        runtime.recordUsage(id)
        action()
      end
    end

    return wrapped
  end

  function M.toggle()
    local ok, err = pcall(function()
      local items, actions = runtime.buildState()
      local payload = hs.json.encode({
        items = items,
        layout = runtime.layoutOrder(),
        strings = {
          title = "Launcher",
          subtitle = "Search, launch, and reorder your workspace",
          searchPlaceholder = "Search windows, apps, commands...",
          edit = "Edit",
          done = "Done",
          all = "All",
          window = "Windows",
          app = "Apps",
          command = "Commands",
          empty = "No matches yet. Try another keyword.",
          hint = "Enter to open · Esc to close · E to edit layout",
          results = "results",
        },
      })

      panel.toggle({
        actions = wrapActions(actions),
        eval = "window.setLauncherState(" .. payload .. "); window.focusLauncher();",
      })
    end)

    if not ok then
      hs.alert.show("Launcher failed to open")
      hs.printf("launcher toggle error: %s", tostring(err))
    end
  end

  function M.registerRuntime(moduleMap)
    runtime.registerModules(moduleMap)
  end

  function M.bindModuleHotkeys()
    runtime.bindModuleHotkeys()
  end

  function M.menubarStatus()
    return runtime.menubarStatus()
  end

  return M
end
