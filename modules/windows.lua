return function(config, helpers)
  local M = {}

  function M.focusedWindow()
    return hs.window.focusedWindow()
  end

  function M.orderedWindows()
    local visible = {}

    for _, window in ipairs(hs.window.orderedWindows()) do
      local title = helpers.normalizeText(window:title())
      local app = window:application()
      local appName = app and helpers.normalizeText(app:name()) or nil

      if title and appName and not window:isMinimized() then
        table.insert(visible, window)
      end
    end

    return visible
  end

  function M.recentAppsFromWindows()
    local apps = {}
    local seen = {}

    for _, window in ipairs(M.orderedWindows()) do
      local app = window:application()
      if app then
        local key = app:bundleID() or app:name()
        if key and not seen[key] then
          seen[key] = true
          table.insert(apps, app)
        end
      end
    end

    return apps
  end

  function M.moveTo(unitName)
    local window = M.focusedWindow()
    if not window then
      hs.alert.show("No focused window")
      return
    end

    local unit = config.units[unitName]
    if unit then
      window:moveToUnit(unit)
    end
  end

  function M.centerFocusedWindow()
    local window = M.focusedWindow()
    if not window then
      hs.alert.show("No focused window")
      return
    end

    window:moveToUnit(config.units.center)
  end

  function M.switchWindowChooser()
    local choices = {}

    for _, window in ipairs(M.orderedWindows()) do
      local app = window:application()
      local appName = app and app:name() or "Unknown App"

      table.insert(choices, {
        text = window:title(),
        subText = appName,
        image = app and helpers.safeIcon(app) or nil,
        window = window,
      })
    end

    helpers.chooseFromList("Switch window", choices, function(choice)
      choice.window:focus()
    end)
  end

  function M.switchAppChooser()
    local choices = {}

    for _, app in ipairs(M.recentAppsFromWindows()) do
      table.insert(choices, {
        text = app:name(),
        subText = app:bundleID() or "Running application",
        image = helpers.safeIcon(app),
        app = app,
      })
    end

    helpers.chooseFromList("Switch app", choices, function(choice)
      choice.app:activate()
    end)
  end

  return M
end
