require("hs.ipc")

local function logStartup(message)
  local file = io.open(os.getenv("HOME") .. "/.hammerspoon/startup.log", "a")
  if not file then
    return
  end

  file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. message .. "\n")
  file:close()
end

local function notify(message)
  hs.printf("%s", message)
  if hs.accessibilityState() then
    hs.alert.show(message, "", 2)
  end
end

logStartup("init start")

local loadErrors = {}

local ok, err = xpcall(function()
  local config = require("config")
  local helpers = require("helpers")
  local moduleToggles = require("modules_enabled")
  local launcher = require("launcher")(config, helpers)

  local function moduleEnabled(name)
    return moduleToggles[name] ~= false
  end

  local function registerModule(name, moduleName)
    if not moduleEnabled(name) then
      logStartup("module skipped: " .. name)
      return nil
    end

    local loadOk, instance = xpcall(function()
      return require(moduleName)(config, helpers)
    end, debug.traceback)

    if not loadOk then
      loadErrors[name] = instance
      logStartup("module failed: " .. name)
      hs.printf("Module %s failed to load: %s", name, instance)
      return nil
    end

    logStartup("module ok: " .. name)
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

  local moduleMap = {
    windows = registerModule("windows", "windows"),
    clipboard = registerModule("clipboard", "clipboard"),
    translate = registerModule("translate", "translate"),
    todo = registerModule("todo", "todo"),
    notes = registerModule("notes", "notes"),
    system = registerModule("system", "system"),
  }

  launcher.registerRuntime(moduleMap)

  if moduleMap.notes then
    moduleMap.notes.setHomeHandler(toggleLauncher)
  end

  if moduleMap.clipboard and moduleMap.clipboard.start then
    moduleMap.clipboard.start()
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
      error("menubar.new() returned nil")
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
    logStartup("menubar failed")
  else
    logStartup("menubar ok")
  end

  logStartup("config loaded")
end, debug.traceback)

if not ok then
  loadErrors.bootstrap = err
  logStartup("bootstrap failed: " .. tostring(err))
  hs.printf("Hammerspoon bootstrap failed: %s", err)
end

if loadErrors.bootstrap then
  notify("Hammerspoon failed to load config")
elseif next(loadErrors) then
  notify("Hammerspoon loaded with module errors")
elseif not hs.accessibilityState() then
  notify("Enable Hammerspoon in Accessibility")
else
  notify("Hammerspoon ready: Cmd+Shift+Space")
end
