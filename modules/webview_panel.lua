local panelFactories = {}

local json = hs.json

local function parseMessage(message)
  if type(message) ~= "table" then
    return nil
  end

  local body = message.body
  if type(body) == "string" then
    local ok, decoded = pcall(json.decode, body)
    if ok and type(decoded) == "table" then
      return decoded
    end
    return nil
  end

  if type(body) == "table" then
    return body
  end

  return message
end

local function createPanel(config, helpers, options)
  local panel = {
    view = nil,
    controller = nil,
    actions = {},
    htmlPath = options.htmlPath,
    html = nil,
    channel = options.channel,
    onMessage = options.onMessage,
    frame = options.frame,
    hideDelay = options.hideDelay or 0.12,
    showDelay = options.showDelay or 0.10,
    lastFrame = nil,
  }

  local function readHtml()
    if panel.html then
      return panel.html
    end

    panel.html = helpers.readFile(panel.htmlPath)
    if not panel.html or panel.html == "" then
      panel.html = "<html><body style='font:16px -apple-system,sans-serif;padding:24px;'>Missing UI asset.</body></html>"
    end
    return panel.html
  end

  local function hide()
    if panel.view then
      panel.view:hide(panel.hideDelay)
    end
  end

  local function updateFrameIfNeeded()
    if not panel.view then
      return
    end

    local nextFrame = panel.frame()
    local last = panel.lastFrame
    if last
      and last.x == nextFrame.x
      and last.y == nextFrame.y
      and last.w == nextFrame.w
      and last.h == nextFrame.h then
      return
    end

    panel.lastFrame = nextFrame
    panel.view:frame(nextFrame)
  end

  local function ensure(createOnly)
    if panel.view then
      if not createOnly then
        updateFrameIfNeeded()
      end
      return
    end

    local webview = require("hs.webview")
    local initialFrame = panel.frame()
    panel.lastFrame = initialFrame

    panel.controller = webview.usercontent.new(panel.channel)
    panel.controller:setCallback(function(message)
      local payload = parseMessage(message)
      if not payload or type(payload) ~= "table" then
        return
      end

      if payload.type == "close" then
        hide()
        return
      end

      if payload.type == "run" and payload.id then
        hide()
        local action = panel.actions[payload.id]
        if action then
          hs.timer.doAfter(0.08, action)
        end
        return
      end

      if panel.onMessage then
        panel.onMessage(payload, hide)
      end
    end)

    panel.view = webview.new(initialFrame, {}, panel.controller)
      :windowStyle("borderless")
      :allowTextEntry(true)
      :transparent(true)
      :shadow(true)
      :deleteOnClose(false)
      :closeOnEscape(true)
      :level(hs.drawing.windowLevels.modalPanel)
      :behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary", "ignoresCycle" })

    panel.view:html(readHtml())
  end

  function panel.hide()
    hide()
  end

  function panel.show(payload)
    ensure(false)

    panel.actions = payload and payload.actions or {}
    panel.view:show(panel.showDelay):bringToFront(true)

    if payload and payload.eval then
      hs.timer.doAfter(0.12, function()
        if panel.view then
          panel.view:evaluateJavaScript(payload.eval, function(_, result)
            if type(result) == "table" and result.message then
              hs.alert.show("Panel UI error")
              hs.printf("webview eval error: %s", result.message)
            end
          end)
        end
      end)
    end
  end

  function panel.toggle(payload)
    ensure(false)

    local hsWindow = panel.view:hswindow()
    if hsWindow and hsWindow:isVisible() then
      hide()
      return
    end

    panel.show(payload)
  end

  function panel.evaluate(script)
    ensure(false)
    if panel.view then
      panel.view:evaluateJavaScript(script)
    end
  end

  function panel.reloadHtml()
    panel.html = nil
    if panel.view then
      panel.view:html(readHtml())
    end
  end

  return panel
end

return function(config, helpers)
  local M = {}

  function M.create(options)
    local key = options.channel
    if not panelFactories[key] then
      panelFactories[key] = createPanel(config, helpers, options)
    end
    return panelFactories[key]
  end

  return M
end
