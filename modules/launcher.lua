return function(config, helpers)
  local M = {}
  local webview = require("hs.webview")

  local launcherView = nil
  local launcherController = nil
  local launcherActions = {}
  local launcherHtml = helpers.readFile(config.assetsDir .. "/launcher.html")

  local function launcherFrame()
    local screen = hs.screen.mainScreen():frame()
    local width = math.min(940, screen.w - 60)
    local height = math.min(720, screen.h - 80)

    return {
      x = screen.x + math.floor((screen.w - width) / 2),
      y = screen.y + math.floor((screen.h - height) / 2),
      w = width,
      h = height,
    }
  end

  local function hideLauncher()
    if launcherView then
      launcherView:hide(0.12)
    end
  end

  local function ensureLauncher()
    if launcherView then
      launcherView:frame(launcherFrame())
      return
    end

    launcherController = webview.usercontent.new("launcher")
    launcherController:setCallback(function(message)
      if type(message) ~= "table" then
        return
      end

      if message.type == "close" then
        hideLauncher()
        return
      end

      if message.type == "run" and message.id then
        hideLauncher()
        local action = launcherActions[message.id]
        if action then
          hs.timer.doAfter(0.08, action)
        end
      end
    end)

    launcherView = webview.new(launcherFrame(), {}, launcherController)
      :windowStyle({})
      :allowTextEntry(true)
      :transparent(true)
      :shadow(true)
      :deleteOnClose(false)
      :closeOnEscape(false)
      :level(hs.drawing.windowLevels.modalPanel)
      :behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary", "ignoresCycle" })
      :windowCallback(function(action, _, state)
        if action == "focusChange" and state == false then
          hideLauncher()
        end
      end)

    launcherView:html(launcherHtml)
  end

  function M.toggle(items, actions)
    ensureLauncher()

    local hsWindow = launcherView:hswindow()
    if hsWindow and hsWindow:isVisible() then
      hideLauncher()
      return
    end

    launcherActions = actions or {}
    launcherView:html(launcherHtml)
    launcherView:show(0.10):bringToFront(true)
    hs.timer.doAfter(0.12, function()
      if launcherView then
        launcherView:evaluateJavaScript("window.setLauncherItems(" .. hs.json.encode(items or {}) .. "); window.focusLauncher();")
      end
    end)
  end

  return M
end
