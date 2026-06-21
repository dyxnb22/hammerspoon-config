return function(config, helpers)
  local M = {}

  local function pathJoin(base, name)
    if string.sub(base, -1) == "/" then
      return base .. name
    end
    return base .. "/" .. name
  end

  local function appNameFromPath(path)
    return path and path:match("([^/]+)%.app/?$")
  end

  local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
  end

  local function stableWindowId(window, app)
    local bundle = app and (app:bundleID() or app:name()) or "unknown"
    local title = window:title() or ""
    return "window:" .. tostring(helpers.hashString(bundle .. "|" .. title))
  end

  local function stableAppId(app)
    local bundle = app and (app:bundleID() or app:name()) or "unknown"
    return "app:" .. bundle
  end

  local function stableCatalogAppId(path)
    return "catalog-app:" .. tostring(helpers.hashString(path or "unknown"))
  end

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

  local function scanApplications(root, depth, seen, collected)
    if not root or depth < 0 then
      return
    end

    local attributes = hs.fs.attributes(root)
    if not attributes or attributes.mode ~= "directory" then
      return
    end

    for entry in hs.fs.dir(root) do
      if entry ~= "." and entry ~= ".." then
        local path = pathJoin(root, entry)
        local mode = hs.fs.attributes(path, "mode")

        if mode == "directory" and entry:match("%.app$") then
          if not seen[path] then
            seen[path] = true
            local name = appNameFromPath(path)
            if name then
              local alias = name
              if path:find("^/System/Applications/") then
                alias = "Apple " .. name
              end

              table.insert(collected, {
                id = stableCatalogAppId(path),
                name = name,
                path = path,
                alias = alias,
              })
            end
          end
        elseif mode == "directory" and depth > 0 then
          scanApplications(path, depth - 1, seen, collected)
        end
      end
    end
  end

  local appCatalogCache = nil
  local appCatalogBuiltAt = 0
  local appCatalogTtl = 120

  function M.installedApps()
    local now = os.time()
    if appCatalogCache and (now - appCatalogBuiltAt) < appCatalogTtl then
      return appCatalogCache
    end

    local roots = {
      "/Applications",
      "/System/Applications",
      "/Applications/Utilities",
      "/System/Applications/Utilities",
      os.getenv("HOME") .. "/Applications",
    }
    local seen = {}
    local collected = {}

    for _, root in ipairs(roots) do
      scanApplications(root, 2, seen, collected)
    end

    table.sort(collected, function(left, right)
      return string.lower(left.name) < string.lower(right.name)
    end)

    appCatalogCache = collected
    appCatalogBuiltAt = now
    return appCatalogCache
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
    M.moveTo("center")
  end

  function M.moveToAdjacentScreen(direction)
    local window = M.focusedWindow()
    if not window then
      hs.alert.show("No focused window")
      return
    end

    local screens = hs.screen.allScreens()
    if #screens < 2 then
      hs.alert.show("Only one screen available")
      return
    end

    local current = window:screen()
    local frame = current:frame()
    local center = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2)
    local bestScreen = nil
    local bestDistance = math.huge

    for _, screen in ipairs(screens) do
      if screen:id() ~= current:id() then
        local targetFrame = screen:frame()
        local targetCenter = hs.geometry.point(
          targetFrame.x + targetFrame.w / 2,
          targetFrame.y + targetFrame.h / 2
        )
        local deltaX = targetCenter.x - center.x
        local deltaY = targetCenter.y - center.y
        local valid = false

        if direction == "left" and deltaX < 0 and math.abs(deltaX) > math.abs(deltaY) then
          valid = true
        elseif direction == "right" and deltaX > 0 and math.abs(deltaX) > math.abs(deltaY) then
          valid = true
        elseif direction == "up" and deltaY < 0 and math.abs(deltaY) >= math.abs(deltaX) then
          valid = true
        elseif direction == "down" and deltaY > 0 and math.abs(deltaY) >= math.abs(deltaX) then
          valid = true
        end

        if valid then
          local distance = math.abs(deltaX) + math.abs(deltaY)
          if distance < bestDistance then
            bestDistance = distance
            bestScreen = screen
          end
        end
      end
    end

    if bestScreen then
      window:moveToScreen(bestScreen)
      window:focus()
    else
      hs.alert.show("No adjacent screen in that direction")
    end
  end

  local layoutPresets = {
    { id = "left", text = "Window Left Half", subText = "Move focused window left", run = function() M.moveTo("left") end },
    { id = "right", text = "Window Right Half", subText = "Move focused window right", run = function() M.moveTo("right") end },
    { id = "top", text = "Window Top Half", subText = "Move focused window top", run = function() M.moveTo("top") end },
    { id = "bottom", text = "Window Bottom Half", subText = "Move focused window bottom", run = function() M.moveTo("bottom") end },
    { id = "maximize", text = "Window Maximize", subText = "Fill the screen", run = function() M.moveTo("max") end },
    { id = "center", text = "Window Center", subText = "Resize and center", run = M.centerFocusedWindow },
    { id = "screen-left", text = "Move To Left Screen", subText = "Send window left", run = function() M.moveToAdjacentScreen("left") end },
    { id = "screen-right", text = "Move To Right Screen", subText = "Send window right", run = function() M.moveToAdjacentScreen("right") end },
  }

  function M.indexContributions(query)
    local items = {}
    local handlers = {}
    local seenApps = {}

    for _, window in ipairs(M.orderedWindows()) do
      local app = window:application()
      local appName = app and app:name() or "Unknown App"
      local actionId = stableWindowId(window, app)
      local title = window:title()

      if helpers.matchQuery(query, title, appName, "window switch") then
        table.insert(items, {
          id = actionId,
          kind = "window",
          title = title,
          subtitle = appName,
          badge = "Window",
          accent = helpers.accentForId(actionId),
          keywords = table.concat({ title, appName, "window" }, " "),
          actions = {
            { id = "focus", label = "Focus", primary = true },
          },
        })
        handlers[actionId] = function()
          window:focus()
        end
        handlers[actionId .. ":focus"] = handlers[actionId]
      end
    end

    for _, app in ipairs(M.recentAppsFromWindows()) do
      local actionId = stableAppId(app)
      local key = app:bundleID() or app:name()
      seenApps[key] = true
      local name = app:name()

      if helpers.matchQuery(query, name, app:bundleID(), "app switch") then
        table.insert(items, {
          id = actionId,
          kind = "app",
          title = name,
          subtitle = "Switch to app",
          badge = "App",
          accent = helpers.accentForId(actionId),
          keywords = table.concat({ name, app:bundleID() or "", "app" }, " "),
          actions = {
            { id = "open", label = "Switch", primary = true },
          },
        })
        handlers[actionId] = function()
          app:activate()
        end
        handlers[actionId .. ":open"] = handlers[actionId]
      end
    end

    local normalizedQuery = helpers.normalizeText(query)
    if normalizedQuery and #normalizedQuery >= 2 then
      for _, app in ipairs(M.installedApps()) do
        local dedupeKey = app.name
        if not seenApps[dedupeKey] and not seenApps[app.path] then
          seenApps[dedupeKey] = true
          seenApps[app.path] = true

          if helpers.matchQuery(query, app.name, app.alias, app.path, "application launch") then
            table.insert(items, {
              id = app.id,
              kind = "app",
              title = app.name,
              subtitle = "Launch application",
              badge = "Application",
              accent = helpers.accentForId(app.id),
              keywords = table.concat({ app.name, app.alias or "", app.path or "" }, " "),
              actions = {
                { id = "open", label = "Launch", primary = true },
              },
            })
            handlers[app.id] = function()
              if hs.application.launchOrFocus(app.name) then
                return
              end
              hs.execute("/usr/bin/open -a " .. shellQuote(app.path))
            end
            handlers[app.id .. ":open"] = handlers[app.id]
          end
        end
      end
    end

    for _, preset in ipairs(layoutPresets) do
      if helpers.matchQuery(query, preset.text, preset.subText, "window layout") then
        local id = "command-" .. preset.id
        table.insert(items, {
          id = id,
          kind = "command",
          title = preset.text,
          subtitle = preset.subText,
          badge = "Layout",
          accent = helpers.accentForId(id),
          keywords = preset.text .. " window layout",
          actions = {
            { id = "open", label = "Run", primary = true },
          },
        })
        handlers[id] = preset.run
        handlers[id .. ":open"] = preset.run
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  return M
end
