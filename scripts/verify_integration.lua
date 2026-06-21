-- Integration checks (logs to ~/.hammerspoon/verify.log)
local logPath = os.getenv("HOME") .. "/.hammerspoon/verify.log"

local function log(line)
  local file = io.open(logPath, "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. line .. "\n")
    file:close()
  end
end

local failures = 0
local round = os.getenv("HS_VERIFY_ROUND") or "1"

local function check(name, ok, detail)
  if ok then
    log("OK [" .. round .. "] " .. name)
  else
    failures = failures + 1
    log("FAIL [" .. round .. "] " .. name .. (detail and (": " .. detail) or ""))
  end
end

log("verify start round=" .. round)

local config = require("config")
local helpers = require("helpers")
local searchIndex = require("search_index")(config, helpers)
local runtime = require("launcher_runtime")(config, helpers)

local modules = {}
for name, enabled in pairs(require("modules_enabled")) do
  if enabled ~= false then
    local loadOk, instance = pcall(function()
      return require(name)(config, helpers)
    end)
    check("module " .. name .. " loads", loadOk)
    if loadOk then
      modules[name] = instance
      check(name .. " has indexContributions", type(instance.indexContributions) == "function")
    end
  end
end

searchIndex.registerModules(modules)
runtime.registerModules(modules)

local function findItem(items, predicate)
  for _, item in ipairs(items or {}) do
    if predicate(item) then
      return item
    end
  end
  return nil
end

local queries = {
  "",
  "todo",
  "translate",
  "clipboard",
  "2+2",
  "github",
  "! echo verify",
  "notes",
  "dark",
  "window",
  "safari",
  "pdf",
}

for _, query in ipairs(queries) do
  local items, handlers = searchIndex.buildSync(query)
  check("buildSync:" .. query, type(items) == "table", "count=" .. #items)

  if query == "2+2" then
    local calc = findItem(items, function(item) return item.kind == "calculator" end)
    check("calculator result", calc and calc.title == "4", calc and calc.title)
  end

  if query == "github" then
    local link = findItem(items, function(item) return item.kind == "link" end)
    check("quick link", link ~= nil)
    check("quick link handler", link and handlers[link.id] ~= nil)
  end

  if query:match("^!") then
    local shell = findItem(items, function(item) return item.kind == "shell" end)
    check("shell item", shell ~= nil)
    check("shell handler", shell and handlers[shell.id] ~= nil)
  end

  if query == "" then
    local window = findItem(items, function(item) return item.kind == "window" end)
    check("default windows present", window ~= nil or #items == 0)
    local catalog = findItem(items, function(item) return item.badge == "Application" end)
    check("catalog hidden on empty query", catalog == nil)
  end

  if query == "safari" then
    local app = findItem(items, function(item)
      return item.kind == "app" and item.title:lower():find("safari", 1, true)
    end)
    check("app search safari", app ~= nil)
  end
end

local syncItems, syncHandlers = runtime.buildState("translate")
check("runtime sync build", #syncItems > 0)
local translateItem = findItem(syncItems, function(item) return item.kind == "ai" end)
check("runtime translate item", translateItem ~= nil)

local asyncDone = false
runtime.buildState("pdf", function(state)
  asyncDone = true
  check("async callback", type(state.items) == "table")
  check("async handlers", type(state.handlers) == "table")
end)

hs.timer.doAfter(2.5, function()
  check("async completed", asyncDone)

  local payload = hs.json.encode({
    items = syncItems,
    loading = false,
    query = "",
    strings = { title = "Spotlight" },
  })
  check("json payload size", #payload < 500000, tostring(#payload))

  local html = helpers.readFile(config.assetsDir .. "/launcher.html")
  check("launcher actions pane", html:find("actionsPane") ~= nil)
  check("launcher search bridge", html:find('type: "search"') ~= nil or html:find("type: 'search'") ~= nil)

  log(string.format("verify done round=%s failures=%d", round, failures))
  if failures > 0 then
    hs.alert.show("Verify round " .. round .. " failed: " .. failures)
  else
    hs.alert.show("Verify round " .. round .. " passed")
  end
end)
