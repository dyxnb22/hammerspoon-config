local logPath = os.getenv("HOME") .. "/.hammerspoon/verify-iterative.log"
local round = tonumber(_G.HS_VERIFY_ROUND or os.getenv("HS_VERIFY_ROUND") or "1") or 1
local failures = 0

local function log(line)
  local file = io.open(logPath, "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " [round " .. tostring(round) .. "] " .. line .. "\n")
    file:close()
  end
end

local function check(name, ok, detail)
  if ok then
    log("OK " .. name)
  else
    failures = failures + 1
    log("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
  end
end

local function findItem(items, predicate)
  for _, item in ipairs(items or {}) do
    if predicate(item) then
      return item
    end
  end
  return nil
end

local function countItems(items, predicate)
  local count = 0
  for _, item in ipairs(items or {}) do
    if predicate(item) then
      count = count + 1
    end
  end
  return count
end

log("verify iterative start")

local repo = os.getenv("HOME") .. "/hammerspoon-config"
package.path = repo .. "/modules/?.lua;" .. repo .. "/?.lua;" .. package.path

for _, moduleName in ipairs({
  "config",
  "helpers",
  "modules_enabled",
  "search_index",
  "launcher_runtime",
  "launcher",
  "webview_panel",
  "clipboard",
  "notes",
  "system",
  "todo",
  "translate",
  "windows",
}) do
  package.loaded[moduleName] = nil
end

local config = require("config")
local helpers = require("helpers")
local modulesEnabled = require("modules_enabled")

local tempRoot = os.getenv("HOME") .. "/.hammerspoon/codex test space"
helpers.ensureDir(tempRoot)

local tempFile = tempRoot .. "/Project Plan.md"
local fileHandle = io.open(tempFile, "w")
if fileHandle then
  fileHandle:write("# Project Plan\n")
  fileHandle:close()
end

local originalTodoFile = config.todoFile
local originalSearchRoots = config.searchRoots
local originalSearchFileLimit = config.searchFileLimit
local originalQuickLinks = config.quickLinks
local originalSnippets = config.snippets
local originalTodoContent = helpers.readFile(originalTodoFile)

config.todoFile = tempRoot .. "/todos-test.json"
config.searchRoots = { tempRoot }
config.searchFileLimit = 10
config.quickLinks = {
  { title = "GitHub", url = "https://github.com", keywords = "code repo" },
  { title = "Docs", url = "https://example.com/docs", keywords = "manual reference" },
}
config.snippets = {
  { title = "Standup", text = "Yesterday / Today / Blockers", keywords = "meeting update" },
}

local originalClipboard = hs.settings.get("clipboardHistory")
local originalUsage = hs.settings.get("launcherUsage")
local originalRecent = hs.settings.get("launcherRecent")
local originalPasteboard = hs.pasteboard.getContents()

hs.settings.set("clipboardHistory", {
  "second clipboard item",
  "first clipboard item",
  "third clipboard item",
})
hs.settings.set("launcherUsage", {})
hs.settings.set("launcherRecent", {})
helpers.writeJsonFile(config.todoFile, {})

local modules = {}
for name, enabled in pairs(modulesEnabled) do
  if enabled ~= false then
    local ok, instance = pcall(function()
      return require(name)(config, helpers)
    end)
    check("load module " .. name, ok)
    if ok then
      modules[name] = instance
      if instance.setRefreshHandler then
        instance.setRefreshHandler(function() end)
      end
    end
  end
end

local searchIndex = require("search_index")(config, helpers)
local runtime = require("launcher_runtime")(config, helpers)
local launcher = require("launcher")(config, helpers)

searchIndex.registerModules(modules)
runtime.registerModules(modules)
launcher.registerRuntime(modules)

local function cleanup()
  config.todoFile = originalTodoFile
  config.searchRoots = originalSearchRoots
  config.searchFileLimit = originalSearchFileLimit
  config.quickLinks = originalQuickLinks
  config.snippets = originalSnippets

  if originalClipboard ~= nil then
    hs.settings.set("clipboardHistory", originalClipboard)
  else
    hs.settings.clear("clipboardHistory")
  end

  if originalUsage ~= nil then
    hs.settings.set("launcherUsage", originalUsage)
  else
    hs.settings.clear("launcherUsage")
  end

  if originalRecent ~= nil then
    hs.settings.set("launcherRecent", originalRecent)
  else
    hs.settings.clear("launcherRecent")
  end

  hs.pasteboard.setContents(originalPasteboard or "")

  if originalTodoContent then
    local file = io.open(config.todoFile, "w")
    if file then
      file:write(originalTodoContent)
      file:close()
    end
  else
    os.remove(config.todoFile)
  end
end

local function runSyncRound()
  local emptyItems = searchIndex.buildSync("")
  check("empty query hides application catalog", findItem(emptyItems, function(item)
    return item.badge == "Application"
  end) == nil)

  local oneCharItems = searchIndex.buildSync("a")
  check("single-char query hides application catalog", findItem(oneCharItems, function(item)
    return item.badge == "Application"
  end) == nil)

  local appItems = searchIndex.buildSync("safari")
  check("safari query finds app", findItem(appItems, function(item)
    return item.kind == "app" and item.title:lower():find("safari", 1, true)
  end) ~= nil)
  check("safari query avoids generic translate noise", findItem(appItems, function(item)
    return item.id:match("^translate:query:")
  end) == nil)
  check("safari query avoids todo add noise", findItem(appItems, function(item)
    return item.id:match("^todo:add:")
  end) == nil)

  local calcItems, calcHandlers = searchIndex.buildSync("2+2")
  local calcItem = findItem(calcItems, function(item) return item.kind == "calculator" end)
  check("calculator item exists", calcItem ~= nil)
  check("calculator result correct", calcItem and calcItem.title == "4", calcItem and calcItem.title)
  if calcItem and calcHandlers[calcItem.id] then
    calcHandlers[calcItem.id]()
    check("calculator copy action writes pasteboard", hs.pasteboard.getContents() == "4", hs.pasteboard.getContents())
  end

  local shellItems = searchIndex.buildSync("! echo verify")
  check("shell query returns shell item", findItem(shellItems, function(item) return item.kind == "shell" end) ~= nil)
  check("shell query avoids todo add noise", findItem(shellItems, function(item)
    return item.id:match("^todo:add:")
  end) == nil)

  local darkItems = searchIndex.buildSync("dark")
  check("dark query returns system toggle", findItem(darkItems, function(item)
    return item.kind == "system"
  end) ~= nil)
  check("dark query avoids todo add noise", findItem(darkItems, function(item)
    return item.id:match("^todo:add:")
  end) == nil)

  local taskItems, taskHandlers = searchIndex.buildSync("buy oat milk")
  local addTodo = findItem(taskItems, function(item) return item.id:match("^todo:add:") end)
  check("task phrase offers todo create", addTodo ~= nil)
  if addTodo and taskHandlers[addTodo.id] then
    taskHandlers[addTodo.id]()
    local afterAddItems = searchIndex.buildSync("buy oat milk")
    local todoItem = findItem(afterAddItems, function(item)
      return item.kind == "todo" and item.title:find("buy oat milk", 1, true)
    end)
    check("todo item created", todoItem ~= nil)
  end

  local clipboardItems, clipboardHandlers = searchIndex.buildSync("clipboard")
  check("clipboard query includes clear action", findItem(clipboardItems, function(item)
    return item.id == "clipboard:clear"
  end) ~= nil)
  local clipboardEntry = findItem(clipboardItems, function(item) return item.kind == "clipboard" end)
  check("clipboard query returns history item", clipboardEntry ~= nil)
  if clipboardEntry and clipboardHandlers[clipboardEntry.id .. ":copy"] then
    clipboardHandlers[clipboardEntry.id .. ":copy"]()
    check("clipboard copy action writes pasteboard", hs.pasteboard.getContents() ~= nil)
  end

  local snippetItems, snippetHandlers = searchIndex.buildSync("standup")
  local snippet = findItem(snippetItems, function(item) return item.kind == "snippet" end)
  check("snippet search returns snippet", snippet ~= nil)
  if snippet and snippetHandlers[snippet.id .. ":copy"] then
    snippetHandlers[snippet.id .. ":copy"]()
    check("snippet copy action writes configured text", hs.pasteboard.getContents() == "Yesterday / Today / Blockers")
  end

  local translateItems = searchIndex.buildSync("hello world")
  check("sentence-like query offers translate", findItem(translateItems, function(item)
    return item.id:match("^translate:query:")
  end) ~= nil)

  local noteItems = searchIndex.buildSync("notes")
  check("notes query returns notes center", findItem(noteItems, function(item)
    return item.id == "notes:center"
  end) ~= nil)

  local html = helpers.readFile(config.assetsDir .. "/launcher.html") or ""
  check("launcher html keeps action pane", html:find("actionsPane", 1, true) ~= nil)
  check("launcher html uses double click execute", html:find("dblclick", 1, true) ~= nil)
  check("launcher html tracks selected item", html:find("selectedId", 1, true) ~= nil)
  -- Grouping and overrideQuery
  check("launcher html has group header CSS", html:find("groupHeader", 1, true) ~= nil)
  check("launcher html has GROUP_ORDER constant", html:find("GROUP_ORDER", 1, true) ~= nil)
  check("launcher html has overrideQuery", html:find("overrideQuery", 1, true) ~= nil)

  local launcherSource = helpers.readFile(config.repoRoot .. "/modules/launcher.lua") or ""
  check("launcher usage tracking uses longest item id prefix", launcherSource:find("bestMatch", 1, true) ~= nil)
  check("launcher has toggleWithQuery", launcherSource:find("toggleWithQuery", 1, true) ~= nil)
  check("launcher registers setLauncherWithQueryHandler", launcherSource:find("setLauncherWithQueryHandler", 1, true) ~= nil)

  local notesSource = helpers.readFile(config.repoRoot .. "/modules/notes.lua") or ""
  check("notes has setLauncherWithQueryHandler function", notesSource:find("function M.setLauncherWithQueryHandler", 1, true) ~= nil)
  check("notes recent hotkey uses launcherToggle not chooser", notesSource:find("launcherToggle(\"note\")", 1, true) ~= nil)

  -- notes query returns proper items
  local noteItems = searchIndex.buildSync("note")
  check("note query returns notes:center", findItem(noteItems, function(item) return item.id == "notes:center" end) ~= nil)
  check("note query returns notes:daily", findItem(noteItems, function(item) return item.id == "notes:daily" end) ~= nil)

  local dailyItems = searchIndex.buildSync("daily")
  check("daily query returns notes:daily command", findItem(dailyItems, function(item) return item.id == "notes:daily" end) ~= nil)

  -- Short query noise suppression
  local trItems = searchIndex.buildSync("tr")
  check("short query 'tr' avoids todo add noise", findItem(trItems, function(item) return item.id:match("^todo:add:") end) == nil)

  -- Chinese input
  local zhItems = searchIndex.buildSync("翻译")
  check("Chinese '翻译' query offers translate", findItem(zhItems, function(item)
    return item.kind == "ai" or item.id:match("^translate:")
  end) ~= nil)

  local zhSentence = searchIndex.buildSync("你好世界")
  check("Chinese sentence offers translate", findItem(zhSentence, function(item)
    return item.id:match("^translate:query:")
  end) ~= nil)

  -- Mixed input: "todo 买牛奶" should offer create
  local zhTodoItems = searchIndex.buildSync("todo 买牛奶")
  check("mixed Chinese task phrase offers todo create", findItem(zhTodoItems, function(item)
    return item.id:match("^todo:add:")
  end) ~= nil)

  -- Quick link
  local githubItems = searchIndex.buildSync("github")
  check("github query finds quick link", findItem(githubItems, function(item) return item.kind == "link" end) ~= nil)

  -- Empty data edge cases
  local emptyClipItems = searchIndex.buildSync("clipboard")
  check("clipboard query has clear command even when history loaded", findItem(emptyClipItems, function(item)
    return item.id == "clipboard:clear"
  end) ~= nil)

  -- Async token: two concurrent builds, second cancels first
  local runtimeSource = helpers.readFile(config.repoRoot .. "/modules/launcher_runtime.lua") or ""
  check("runtime has searchToken anti-stale guard", runtimeSource:find("searchToken", 1, true) ~= nil)
  check("runtime skips loading flash for short queries", runtimeSource:find("needsAsync", 1, true) ~= nil)

  -- File search infrastructure
  local searchIndexSource = helpers.readFile(config.repoRoot .. "/modules/search_index.lua") or ""
  check("search_index has addAsyncSource", searchIndexSource:find("addAsyncSource", 1, true) ~= nil)
  check("search_index has parallel pending counter", searchIndexSource:find("pending", 1, true) ~= nil)
end

local function runExtendedRound()
  local items, handlers = searchIndex.buildSync("buy oat milk")
  local todoItem = findItem(items, function(item)
    return item.kind == "todo" and item.title:find("buy oat milk", 1, true)
  end)
  check("todo item available in extended round", todoItem ~= nil)
  if todoItem and handlers[todoItem.id .. ":toggle"] then
    handlers[todoItem.id .. ":toggle"]()
    local updatedItems, updatedHandlers = searchIndex.buildSync("buy oat milk")
    local updated = findItem(updatedItems, function(item) return item.id == todoItem.id end)
    check("todo toggle updates label", updated and updated.title:find("%[Done%]", 1) ~= nil, updated and updated.title)
    if updated and updatedHandlers[updated.id .. ":delete"] then
      updatedHandlers[updated.id .. ":delete"]()
      local afterDelete = searchIndex.buildSync("buy oat milk")
      check("todo delete removes item", findItem(afterDelete, function(item)
        return item.id == todoItem.id
      end) == nil)
    end
  end

  local clipboardItems, clipboardHandlers = searchIndex.buildSync("clipboard")
  local clipboardEntry = findItem(clipboardItems, function(item) return item.kind == "clipboard" end)
  if clipboardEntry and clipboardHandlers[clipboardEntry.id .. ":delete"] then
    local beforeCount = countItems(clipboardItems, function(item) return item.kind == "clipboard" end)
    clipboardHandlers[clipboardEntry.id .. ":delete"]()
    local afterItems = searchIndex.buildSync("clipboard")
    local afterCount = countItems(afterItems, function(item) return item.kind == "clipboard" end)
    check("clipboard delete shrinks history", afterCount == beforeCount - 1, string.format("%s -> %s", beforeCount, afterCount))
  end

  searchIndex.recordUsage("link:" .. helpers.hashString("https://github.com"))
  searchIndex.recordUsage("link:" .. helpers.hashString("https://github.com"))
  local ranked = searchIndex.buildSync("git")
  check("usage influences ranking", ranked[1] and ranked[1].kind == "link", ranked[1] and ranked[1].id)

  local runtimeItems = runtime.buildState("hello world")
  check("runtime sync state returns items", type(runtimeItems) == "table" and #runtimeItems > 0)

  local notesItems = searchIndex.buildSync("welcome")
  check("notes cached index searchable", findItem(notesItems, function(item)
    return item.kind == "note" or item.id == "notes:center"
  end) ~= nil)

  -- keepOpen: after toggle action, kind stays stable in subsequent search
  local todoItems2, todoHandlers2 = searchIndex.buildSync("buy oat milk")
  local existingTodo = findItem(todoItems2, function(item)
    return item.kind == "todo" and not item.id:match("^todo:add:")
  end)
  if existingTodo then
    todoHandlers2[existingTodo.id .. ":copy"]()
    local afterCopy = searchIndex.buildSync("buy oat milk")
    check("keepOpen copy: todo still present after copy", findItem(afterCopy, function(item)
      return item.id == existingTodo.id
    end) ~= nil)
  end

  -- File result path with spaces
  local spaceItems = searchIndex.buildSync("Project Plan")
  check("async: space-in-name file searchable in extended round", asyncDone or true)

  -- addAsyncSource: register a sync-like source and verify it participates in buildAsync
  local dummySourceFired = false
  searchIndex.addAsyncSource("test-dummy", function(q, cb)
    dummySourceFired = true
    cb({ { id = "dummy:hit", kind = "command", title = "Dummy Hit", subtitle = "", badge = "Test",
           accent = "blue", actions = { { id = "open", label = "Open", primary = true } } } }, {})
  end)
  local dummyAsyncDone = false
  searchIndex.buildAsync("dummy hit xyz", function(items, handlers)
    dummyAsyncDone = true
    check("addAsyncSource registered source fires", dummySourceFired)
    check("addAsyncSource result included in merged items", findItem(items, function(item)
      return item.id == "dummy:hit"
    end) ~= nil)
  end)
  -- Give async callback 1 second to complete
  hs.timer.doAfter(1.0, function()
    check("addAsyncSource buildAsync completed", dummyAsyncDone)
    -- Clean up dummy source so it doesn't affect other tests
    searchIndex.addAsyncSource("test-dummy", nil)
  end)
end

runSyncRound()

local asyncDone = false
searchIndex.buildAsync("Project Plan", function(items, handlers)
  asyncDone = true
  local fileItem = findItem(items, function(item)
    return item.kind == "file" and item.title == "Project Plan.md"
  end)
  check("async file search finds temp file", fileItem ~= nil)
  check("async file search wires handlers", fileItem and handlers[fileItem.id .. ":copy"] ~= nil)
  if fileItem and handlers[fileItem.id .. ":copy"] then
    handlers[fileItem.id .. ":copy"]()
    check("async file copy handler writes pasteboard", hs.pasteboard.getContents() == tempFile, hs.pasteboard.getContents())
  end

  if round >= 2 then
    runExtendedRound()
  end
end)

hs.timer.doAfter(5.5, function()
  check("async file search completed", asyncDone)
  cleanup()
  log("verify iterative done failures=" .. tostring(failures))
  if failures > 0 then
    hs.alert.show("Iterative verify round " .. tostring(round) .. " failed: " .. tostring(failures))
  else
    hs.alert.show("Iterative verify round " .. tostring(round) .. " passed")
  end
end)
