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

return function(config, helpers)
  return function(options)
    local panel = {
      view = nil,
      controller = nil,
      actions = {},
      html = helpers.readFile(options.htmlPath),
      channel = options.channel,
      onMessage = options.onMessage,
      frame = options.frame,
      hideDelay = options.hideDelay or 0.12,
      showDelay = options.showDelay or 0.10,
    }

    local function hide()
      if panel.view then
        panel.view:hide(panel.hideDelay)
      end
    end

    local function ensure()
      if panel.view then
        panel.view:frame(panel.frame())
        return
      end

      local webview = require("hs.webview")

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

      panel.view = webview.new(panel.frame(), {}, panel.controller)
        :windowStyle("borderless")
        :allowTextEntry(true)
        :transparent(true)
        :shadow(true)
        :deleteOnClose(false)
        :closeOnEscape(false)
        :level(hs.drawing.windowLevels.modalPanel)
        :behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary", "ignoresCycle" })
        :windowCallback(function(action, _, state)
          if action == "focusChange" and state == false then
            hide()
          end
        end)

      if not panel.html or panel.html == "" then
        panel.html = "<html><body style='font:16px -apple-system,sans-serif;padding:24px;'>Missing UI asset.</body></html>"
      end

      panel.view:html(panel.html)
    end

    function panel.hide()
      hide()
    end

    function panel.show(payload)
      ensure()

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
      ensure()

      local hsWindow = panel.view:hswindow()
      if hsWindow and hsWindow:isVisible() then
        hide()
        return
      end

      panel.show(payload)
    end

    function panel.evaluate(script)
      ensure()
      if panel.view then
        panel.view:evaluateJavaScript(script)
      end
    end

    return panel
  end
end
