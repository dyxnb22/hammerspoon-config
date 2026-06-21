return function(config, helpers)
  local M = {}
  local appCatalogCache = nil
  local appCatalogBuiltAt = 0
  local appCatalogTtl = 120

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

  function M.launcherItems(makeItem)
    local items = {}
    local actions = {}
    local seenApps = {}

    for _, window in ipairs(M.orderedWindows()) do
      local app = window:application()
      local appName = app and app:name() or "Unknown App"
      local actionId = stableWindowId(window, app)

      actions[actionId] = function()
        window:focus()
      end

      table.insert(items, makeItem(
        actionId,
        "window",
        window:title(),
        appName,
        "Recent Window"
      ))
    end

    for _, app in ipairs(M.recentAppsFromWindows()) do
      local actionId = stableAppId(app)
      local key = app:bundleID() or app:name()
      seenApps[key] = true

      actions[actionId] = function()
        app:activate()
      end

      local item = makeItem(
        actionId,
        "app",
        app:name(),
        "Switch to app",
        "Recent App"
      )
      item.searchText = table.concat({
        app:name() or "",
        app:bundleID() or "",
      }, " ")
      table.insert(items, item)
    end

    for _, app in ipairs(M.installedApps()) do
      local dedupeKey = app.name
      if not seenApps[dedupeKey] and not seenApps[app.path] then
        seenApps[dedupeKey] = true
        seenApps[app.path] = true

        actions[app.id] = function()
          if hs.application.launchOrFocus(app.name) then
            return
          end
          hs.execute("/usr/bin/open -a " .. shellQuote(app.path))
        end

        local item = makeItem(
          app.id,
          "app",
          app.name,
          "Launch installed app",
          "Application"
        )
        item.searchText = table.concat({
          app.name or "",
          app.alias or "",
          app.path or "",
        }, " ")
        table.insert(items, item)
      end
    end

    return items, actions
  end

  function M.launcherCommands()
    return {
      {
        id = "windows",
        text = "Switch Window",
        subText = "Jump to an open window",
        run = M.switchWindowChooser,
      },
      {
        id = "apps",
        text = "Switch App",
        subText = "Jump to a recent app",
        run = M.switchAppChooser,
      },
      {
        id = "left",
        text = "Window Left Half",
        subText = "Move the focused window to the left half",
        run = function()
          M.moveTo("left")
        end,
      },
      {
        id = "right",
        text = "Window Right Half",
        subText = "Move the focused window to the right half",
        run = function()
          M.moveTo("right")
        end,
      },
      {
        id = "top",
        text = "Window Top Half",
        subText = "Move the focused window to the top half",
        run = function()
          M.moveTo("top")
        end,
      },
      {
        id = "bottom",
        text = "Window Bottom Half",
        subText = "Move the focused window to the bottom half",
        run = function()
          M.moveTo("bottom")
        end,
      },
      {
        id = "maximize",
        text = "Window Maximize",
        subText = "Expand the focused window to fill the screen",
        run = function()
          M.moveTo("max")
        end,
      },
      {
        id = "center",
        text = "Window Center",
        subText = "Resize and center the focused window",
        run = M.centerFocusedWindow,
      },
      {
        id = "screen-left",
        text = "Move Window To Left Screen",
        subText = "Send focused window to the screen on the left",
        run = function()
          M.moveToAdjacentScreen("left")
        end,
      },
      {
        id = "screen-right",
        text = "Move Window To Right Screen",
        subText = "Send focused window to the screen on the right",
        run = function()
          M.moveToAdjacentScreen("right")
        end,
      },
    }
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
