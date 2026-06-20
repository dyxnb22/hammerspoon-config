return function(config, helpers)
  local createPanel = require("webview_panel")(config, helpers)
  local settings = hs.settings
  local layoutKey = "launcherCardOrder"

  local function loadLayoutOrder()
    return settings.get(layoutKey) or {}
  end

  local function saveLayoutOrder(order)
    if type(order) == "table" then
      settings.set(layoutKey, order)
    end
  end

  local function applyLayoutOrder(items)
    local saved = loadLayoutOrder()
    local lookup = {}

    for _, item in ipairs(items or {}) do
      lookup[item.id] = item
    end

    local ordered = {}
    local seen = {}

    for _, id in ipairs(saved) do
      if lookup[id] then
        table.insert(ordered, lookup[id])
        seen[id] = true
      end
    end

    for _, item in ipairs(items or {}) do
      if not seen[item.id] then
        table.insert(ordered, item)
      end
    end

    return ordered
  end

  local panel = createPanel({
    channel = "launcher",
    htmlPath = config.assetsDir .. "/launcher.html",
    frame = function()
      local screen = hs.screen.mainScreen():frame()
      local width = math.min(960, screen.w - 48)
      local height = math.min(740, screen.h - 48)

      return {
        x = screen.x + math.floor((screen.w - width) / 2),
        y = screen.y + math.floor((screen.h - height) / 2),
        w = width,
        h = height,
      }
    end,
    onMessage = function(payload)
      if payload.type == "saveLayout" and payload.order then
        saveLayoutOrder(payload.order)
      end
    end,
  })

  local M = {}

  function M.toggle(items, actions)
    local ok, err = pcall(function()
      local orderedItems = applyLayoutOrder(items or {})
      local payload = hs.json.encode({
        items = orderedItems,
        layout = loadLayoutOrder(),
      })

      panel.toggle({
        actions = actions or {},
        eval = "window.setLauncherState(" .. payload .. "); window.focusLauncher();",
      })
    end)

    if not ok then
      hs.alert.show("Launcher failed to open")
      hs.printf("launcher toggle error: %s", tostring(err))
    end
  end

  return M
end
