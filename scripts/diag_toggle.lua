local logPath = os.getenv("HOME") .. "/.hammerspoon/diag.log"
local file = io.open(logPath, "a")
local function log(line)
  file:write(os.date("%H:%M:%S") .. " " .. line .. "\n")
  file:flush()
end

local ok, err = pcall(function()
  log("toggle test start")
  local config = require("config")
  local helpers = require("helpers")
  local launcher = require("launcher")(config, helpers)
  local runtime = require("launcher_runtime")(config, helpers)
  local modules = {}
  for name in pairs(require("modules_enabled")) do
    modules[name] = require(name)(config, helpers)
  end
  runtime.registerModules(modules)
  launcher.registerRuntime(modules)
  launcher.toggle()
  log("toggle called ok")
end)

if not ok then
  log("toggle failed: " .. tostring(err))
end

file:close()
