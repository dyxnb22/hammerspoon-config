return function(config, helpers)
  local settings = hs.settings
  local layoutKey = "launcherCardOrder"
  local searchIndex = require("search_index")(config, helpers)

  local M = {}
  local modules = {}
  local searchToken = 0

  local function loadLayoutOrder()
    return settings.get(layoutKey) or {}
  end

  local function saveLayoutOrder(order)
    if type(order) == "table" then
      settings.set(layoutKey, order)
    end
  end

  local function applyLayoutOrder(items)
    local saved = loadLayoutOrder()
    if #saved == 0 then
      return items
    end

    local lookup = {}
    local ordered = {}
    local seen = {}

    for _, item in ipairs(items or {}) do
      lookup[item.id] = item
    end

    for _, id in ipairs(saved) do
      if lookup[id] then
        table.insert(ordered, lookup[id])
        seen[id] = true
      end
    end

    for _, item in ipairs(items or {}) do
      if not seen[item.id] then
        table.insert(ordered, item)
      end
    end

    return ordered
  end

  local function mergeHandlers(target, source)
    for key, fn in pairs(source or {}) do
      target[key] = fn
    end
  end

  local function mergeItems(syncItems, asyncItems, query)
    local seen = {}
    local merged = {}

    for _, item in ipairs(syncItems or {}) do
      if not seen[item.id] then
        seen[item.id] = true
        table.insert(merged, item)
      end
    end

    for _, item in ipairs(asyncItems or {}) do
      if not seen[item.id] then
        seen[item.id] = true
        table.insert(merged, item)
      end
    end

    if (query or "") == "" then
      merged = applyLayoutOrder(merged)
    end

    return searchIndex.rankItems(merged, query)
  end

  function M.buildState(query, callback)
    query = query or ""
    local syncItems, syncHandlers = searchIndex.buildSync(query)

    if not callback then
      return syncItems, syncHandlers, false
    end

    searchToken = searchToken + 1
    local token = searchToken

    -- Only show loading indicator for queries long enough to trigger async file search
    local normalized = helpers.normalizeText(query)
    local needsAsync = normalized ~= nil and #normalized >= 2

    if needsAsync then
      callback({
        items = syncItems,
        handlers = syncHandlers,
        loading = true,
        query = query,
      })
    else
      callback({
        items = syncItems,
        handlers = syncHandlers,
        loading = false,
        query = query,
      })
      return
    end

    searchIndex.buildAsync(query, function(asyncItems, asyncHandlers, done)
      if token ~= searchToken then
        return
      end

      local items = mergeItems(syncItems, asyncItems, query)
      local handlers = {}
      mergeHandlers(handlers, syncHandlers)
      mergeHandlers(handlers, asyncHandlers)

      callback({
        items = items,
        handlers = handlers,
        loading = done ~= true,
        query = query,
      })
    end)
  end

  function M.recordUsage(id)
    searchIndex.recordUsage(id)
  end

  function M.registerModules(moduleMap)
    modules = moduleMap or {}
    searchIndex.registerModules(modules)
  end

  function M.saveLayout(order)
    saveLayoutOrder(order)
  end

  function M.layoutOrder()
    return loadLayoutOrder()
  end

  function M.bindModuleHotkeys()
    for _, moduleInstance in pairs(modules) do
      if moduleInstance.bindHotkeys then
        xpcall(moduleInstance.bindHotkeys, debug.traceback)
      end
    end
  end

  function M.menubarStatus()
    local names = {}
    for name, instance in pairs(modules) do
      if instance then
        table.insert(names, name)
      end
    end
    table.sort(names)
    return table.concat(names, " · ")
  end

  return M
end
