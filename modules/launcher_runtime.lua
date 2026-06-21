return function(config, helpers)
  local settings = hs.settings
  local layoutKey = "launcherCardOrder"
  local usageKey = "launcherUsage"
  local cacheTtl = 2

  local M = {}
  local modules = {}
  local cache = {
    at = 0,
    items = nil,
    actions = nil,
  }

  local function loadLayoutOrder()
    return settings.get(layoutKey) or {}
  end

  local function saveLayoutOrder(order)
    if type(order) == "table" then
      settings.set(layoutKey, order)
    end
  end

  local function loadUsage()
    return settings.get(usageKey) or {}
  end

  function M.recordUsage(id)
    if not id then
      return
    end

    local usage = loadUsage()
    usage[id] = (usage[id] or 0) + 1
    settings.set(usageKey, usage)
  end

  local function applyLayoutOrder(items)
    local saved = loadLayoutOrder()
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

  local function sortItems(items)
    local usage = loadUsage()
    table.sort(items, function(left, right)
      local leftUsage = usage[left.id] or 0
      local rightUsage = usage[right.id] or 0
      if leftUsage ~= rightUsage then
        return leftUsage > rightUsage
      end
      return (left.rank or 0) < (right.rank or 0)
    end)
    return items
  end

  local function makeItem(id, kind, title, subtitle, badge)
    return {
      id = id,
      kind = kind,
      title = title,
      subtitle = subtitle,
      badge = badge,
      accent = helpers.accentForId(id),
    }
  end

  local function buildDynamicItems()
    local items = {}
    local actions = {}
    local rank = 0
    local windows = modules.windows

    if not windows or not windows.launcherItems then
      return items, actions
    end

    local dynamicItems, dynamicActions = windows.launcherItems(makeItem)
    for _, item in ipairs(dynamicItems or {}) do
      rank = rank + 1
      item.rank = rank
      table.insert(items, item)
    end

    for id, action in pairs(dynamicActions or {}) do
      actions[id] = action
    end

    return items, actions
  end

  local function buildCommandItems()
    local items = {}
    local actions = {}
    local rank = 0

    for _, moduleInstance in pairs(modules) do
      if moduleInstance.launcherCommands then
        for _, command in ipairs(moduleInstance.launcherCommands()) do
          local actionId = "command-" .. command.id
          rank = rank + 1
          actions[actionId] = command.run
          table.insert(items, makeItem(
            actionId,
            "command",
            command.text,
            command.subText,
            command.badge or "Command"
          ))
          items[#items].rank = rank
        end
      end
    end

    return items, actions
  end

  function M.buildState()
    local now = os.time()
    if cache.items and cache.actions and (now - cache.at) < cacheTtl then
      return cache.items, cache.actions
    end

    local commandItems, commandActions = buildCommandItems()
    local dynamicItems, dynamicActions = buildDynamicItems()

    local items = {}
    local actions = {}

    for _, item in ipairs(commandItems) do
      table.insert(items, item)
    end
    for id, action in pairs(commandActions) do
      actions[id] = action
    end

    for _, item in ipairs(dynamicItems) do
      table.insert(items, item)
    end
    for id, action in pairs(dynamicActions) do
      actions[id] = action
    end

    items = applyLayoutOrder(items)
    for index, item in ipairs(items) do
      item.rank = index
    end

    if #loadLayoutOrder() == 0 then
      items = sortItems(items)
    end

    local usage = loadUsage()
    for _, item in ipairs(items) do
      item.usageCount = usage[item.id] or 0
    end

    cache.at = now
    cache.items = items
    cache.actions = actions
    return items, actions
  end

  function M.invalidateCache()
    cache.at = 0
    cache.items = nil
    cache.actions = nil
  end

  function M.registerModules(moduleMap)
    modules = moduleMap or {}
  end

  function M.saveLayout(order)
    saveLayoutOrder(order)
    M.invalidateCache()
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
