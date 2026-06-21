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

  return instance
end

local function toggleLauncher()
  launcher.toggle()
end

hs.hotkey.bind(config.entryHotkey.modifiers, config.entryHotkey.key, toggleLauncher)

if config.launcherFallbackHotkey then
  hs.hotkey.bind(
    config.launcherFallbackHotkey.modifiers,
    config.launcherFallbackHotkey.key,
    toggleLauncher
  )
end

local windows = registerModule("windows", "windows")
local clipboard = registerModule("clipboard", "clipboard")
local translate = registerModule("translate", "translate")
local todo = registerModule("todo", "todo")
local notes = registerModule("notes", "notes")

local moduleMap = {
  windows = windows,
  clipboard = clipboard,
  translate = translate,
  todo = todo,
  notes = notes,
}

launcher.registerRuntime(moduleMap)

if notes then
  notes.setHomeHandler(toggleLauncher)
end

if clipboard and clipboard.start then
  clipboard.start()
end

math.randomseed(os.time())

hs.hotkey.bind(config.hyper, "R", function()
  hs.reload()
end)

launcher.bindModuleHotkeys()

local menuBarOk = xpcall(function()
  local menubar = require("hs.menubar")
  local menuBar = menubar.new()
  if not menuBar then
    return
  end

  menuBar:setTitle("HS")
  menuBar:setMenu(function()
    local status = launcher.menubarStatus()
    return {
      { title = "Modules: " .. (status ~= "" and status or "none"), disabled = true },
      { title = "-" },
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

logStartup("config loaded")

if next(loadErrors) then
  hs.alert.show("Hammerspoon loaded with module errors")
elseif not hs.accessibilityState() then
  hs.alert.show("Enable Hammerspoon in Accessibility")
else
  hs.alert.show("Hammerspoon ready: Cmd+Shift+Space")
end
