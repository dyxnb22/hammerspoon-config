require("hs.ipc")

local function logStartup(message)
  local file = io.open(os.getenv("HOME") .. "/.hammerspoon/startup.log", "a")
  if not file then
    return
  end

  file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. message .. "\n")
  file:close()
end

logStartup("init start")

local config = require("config")
local helpers = require("helpers")
local moduleToggles = require("modules_enabled")
local launcher = require("launcher")(config, helpers)

local loadedModules = {}
local commandDefinitions = {}
local loadErrors = {}

local function moduleEnabled(name)
  return moduleToggles[name] ~= false
end

local function registerModule(name, moduleName)
  if not moduleEnabled(name) then
    return nil
  end

  local ok, instance = xpcall(function()
    return require(moduleName)(config, helpers)
  end, debug.traceback)

  if not ok then
    loadErrors[name] = instance
    logStartup("module failed: " .. name)
    hs.printf("Module %s failed to load: %s", name, instance)
    return nil
  end

  loadedModules[name] = instance
  return instance
end

local function addCommand(command)
  table.insert(commandDefinitions, command)
end

local function launcherAccentForIndex(index)
  local accents = {
    "blue",
    "indigo",
    "teal",
    "green",
    "orange",
    "pink",
  }

  return accents[((index - 1) % #accents) + 1]
end

local function makeLauncherItem(actionId, kind, title, subtitle, badge, accent)
  return {
    id = actionId,
    kind = kind,
    title = title,
    subtitle = subtitle,
    badge = badge,
    accent = accent,
  }
end

local function buildLauncherState()
  local items = {}
  local actions = {}
  local index = 0
  local windows = loadedModules.windows

  for _, command in ipairs(commandDefinitions) do
    local actionId = "command-" .. command.id
    index = index + 1
    actions[actionId] = command.run

    table.insert(items, makeLauncherItem(
      actionId,
      "command",
      command.text,
      command.subText,
      "Command",
      launcherAccentForIndex(index)
    ))
  end

  if windows then
    for _, window in ipairs(windows.orderedWindows()) do
      local app = window:application()
      local appName = app and app:name() or "Unknown App"
      local actionId = "window-" .. tostring(index + 1)
      index = index + 1

      actions[actionId] = function()
        window:focus()
      end

      table.insert(items, makeLauncherItem(
        actionId,
        "window",
        window:title(),
        appName,
        "Recent Window",
        launcherAccentForIndex(index)
      ))
    end

    for _, app in ipairs(windows.recentAppsFromWindows()) do
      local actionId = "app-" .. tostring(index + 1)
      index = index + 1

      actions[actionId] = function()
        app:activate()
      end

      table.insert(items, makeLauncherItem(
        actionId,
        "app",
        app:name(),
        "Switch to app",
        "Recent App",
        launcherAccentForIndex(index)
      ))
    end
  end

  return items, actions
end

local function toggleLauncher()
  local items, actions = buildLauncherState()
  launcher.toggle(items, actions)
end

local function bindLauncherHotkeys()
  hs.hotkey.bind(config.entryHotkey.modifiers, config.entryHotkey.key, toggleLauncher)

  if config.launcherFallbackHotkey then
    hs.hotkey.bind(
      config.launcherFallbackHotkey.modifiers,
      config.launcherFallbackHotkey.key,
      toggleLauncher
    )
  end
end

bindLauncherHotkeys()

local menuBarOk = xpcall(function()
  local menubar = require("hs.menubar")
  local menuBar = menubar.new()
  if not menuBar then
    return
  end

  menuBar:setTitle("HS")
  menuBar:setMenu(function()
    return {
      { title = "Open Launcher", fn = toggleLauncher },
      { title = "Reload Config", fn = hs.reload },
      { title = "-" },
      { title = "Open Config Folder", fn = function()
        hs.execute("open " .. hs.configdir)
      end },
    }
  end)
end, debug.traceback)

if not menuBarOk then
  loadErrors.menubar = true
end

local windows = registerModule("windows", "windows")
local clipboard = registerModule("clipboard", "clipboard")
local translate = registerModule("translate", "translate")
local todo = registerModule("todo", "todo")
local notes = registerModule("notes", "notes")

if clipboard and clipboard.start then
  clipboard.start()
end

math.randomseed(os.time())

if translate then
  addCommand({
    id = "translate",
    text = "Google Translate",
    subText = "Translate selected text or clipboard text",
    keywords = "translate google language",
    run = translate.prompt,
  })
end

if clipboard then
  addCommand({
    id = "clipboard",
    text = "Clipboard History",
    subText = "Browse the last 80 copied items",
    keywords = "clipboard paste copy history",
    run = clipboard.openChooser,
  })
end

if windows then
  addCommand({
    id = "windows",
    text = "Switch Window",
    subText = "Jump to an open window",
    keywords = "window switch recent focus",
    run = windows.switchWindowChooser,
  })
  addCommand({
    id = "apps",
    text = "Switch App",
    subText = "Jump to a recent app",
    keywords = "application app switch launch",
    run = windows.switchAppChooser,
  })
  addCommand({
    id = "left",
    text = "Window Left Half",
    subText = "Move the focused window to the left half",
    keywords = "window left tile",
    run = function()
      windows.moveTo("left")
    end,
  })
  addCommand({
    id = "right",
    text = "Window Right Half",
    subText = "Move the focused window to the right half",
    keywords = "window right tile",
    run = function()
      windows.moveTo("right")
    end,
  })
  addCommand({
    id = "top",
    text = "Window Top Half",
    subText = "Move the focused window to the top half",
    keywords = "window top tile",
    run = function()
      windows.moveTo("top")
    end,
  })
  addCommand({
    id = "bottom",
    text = "Window Bottom Half",
    subText = "Move the focused window to the bottom half",
    keywords = "window bottom tile",
    run = function()
      windows.moveTo("bottom")
    end,
  })
  addCommand({
    id = "maximize",
    text = "Window Maximize",
    subText = "Expand the focused window to fill the screen",
    keywords = "window maximize full screen fill",
    run = function()
      windows.moveTo("max")
    end,
  })
  addCommand({
    id = "center",
    text = "Window Center",
    subText = "Resize and center the focused window",
    keywords = "window center resize",
    run = windows.centerFocusedWindow,
  })
end

if todo then
  addCommand({
    id = "todo",
    text = "TODO",
    subText = "Capture, toggle, and clean up tasks",
    keywords = "todo tasks notes capture",
    run = todo.openChooser,
  })
end

if notes then
  addCommand({
    id = "notes",
    text = "Notes Center",
    subText = "Browse vault, graph links, and open in Typora",
    keywords = "notes typora markdown vault graph",
    run = notes.openCenter,
  })
  addCommand({
    id = "notes-recent",
    text = "Recent Notes",
    subText = "Open a recently edited markdown note",
    keywords = "notes recent typora markdown",
    run = notes.openRecentChooser,
  })
  addCommand({
    id = "notes-daily",
    text = "New Daily Note",
    subText = "Create or open today's journal note",
    keywords = "notes daily journal today typora",
    run = function()
      local path = notes.newDailyNote()
      notes.openInTypora(path)
    end,
  })
end

hs.hotkey.bind(config.hyper, "R", function()
  hs.reload()
end)

if windows then
  hs.hotkey.bind(config.hyper, "H", function()
    windows.moveTo("left")
  end)
  hs.hotkey.bind(config.hyper, "L", function()
    windows.moveTo("right")
  end)
  hs.hotkey.bind(config.hyper, "K", function()
    windows.moveTo("top")
  end)
  hs.hotkey.bind(config.hyper, "J", function()
    windows.moveTo("bottom")
  end)
  hs.hotkey.bind(config.hyper, "F", function()
    windows.moveTo("max")
  end)
  hs.hotkey.bind(config.hyper, "C", windows.centerFocusedWindow)
  hs.hotkey.bind(config.hyper, "A", windows.switchAppChooser)
  hs.hotkey.bind(config.hyper, "W", windows.switchWindowChooser)
end

if clipboard then
  hs.hotkey.bind(config.hyper, "V", clipboard.openChooser)
end

if todo then
  hs.hotkey.bind(config.hyper, "T", todo.openChooser)
end

if translate then
  hs.hotkey.bind(config.hyper, "G", translate.prompt)
end

if notes then
  xpcall(function()
    notes.bindHotkeys()
  end, debug.traceback)
end

logStartup("config loaded")

if next(loadErrors) then
  hs.alert.show("Hammerspoon loaded with module errors")
elseif not hs.accessibilityState() then
  hs.alert.show("Enable Hammerspoon in Accessibility")
else
  hs.alert.show("Hammerspoon ready: Cmd+Shift+Space")
end
