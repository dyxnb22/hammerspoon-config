local logPath = os.getenv("HOME") .. "/.hammerspoon/diag.log"
local f = io.open(logPath, "w")

local function log(msg)
  f:write(msg .. "\n")
  f:flush()
end

local ok, err = pcall(function()
  log("diag start " .. os.date())
  local config = require("config")
  local helpers = require("helpers")
  log("config ok")

  local modules = {}
  for name in pairs(require("modules_enabled")) do
    local t0 = os.clock()
    local loadOk, instance = pcall(function()
      return require(name)(config, helpers)
    end)
    log(string.format("module %s loadOk=%s time=%.3f", name, tostring(loadOk), os.clock() - t0))
    if loadOk then modules[name] = instance end
  end

  local searchIndex = require("search_index")(config, helpers)
  searchIndex.registerModules(modules)

  for _, query in ipairs({ "", "todo", "safari" }) do
    local t0 = os.clock()
    local items, handlers = searchIndex.buildSync(query)
    log(string.format("buildSync %q items=%d time=%.3f", query, #items, os.clock() - t0))
  end

  log("diag done")
end)

if not ok then
  log("diag error: " .. tostring(err))
end

f:close()
