return function(config, helpers)
  local settings = hs.settings
  local usageKey = "launcherUsage"
  local recentKey = "launcherRecent"

  local M = {}
  local modules = {}
  local asyncSources = {}  -- name → function(query, callback)

  local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
  end

  local function loadUsage()
    return settings.get(usageKey) or {}
  end

  local function loadRecent()
    return settings.get(recentKey) or {}
  end

  function M.recordUsage(id)
    if not id then
      return
    end

    local usage = loadUsage()
    usage[id] = (usage[id] or 0) + 1
    settings.set(usageKey, usage)

    local recent = loadRecent()
    for index = #recent, 1, -1 do
      if recent[index] == id then
        table.remove(recent, index)
      end
    end
    table.insert(recent, 1, id)
    while #recent > 40 do
      table.remove(recent)
    end
    settings.set(recentKey, recent)
  end

  local function makeItem(id, kind, title, subtitle, badge, actions, extra)
    local item = {
      id = id,
      kind = kind,
      title = title,
      subtitle = subtitle or "",
      badge = badge or kind,
      accent = helpers.accentForId(id),
      actions = actions or {
        { id = "open", label = "Open", primary = true },
      },
    }

    if extra then
      for key, value in pairs(extra) do
        item[key] = value
      end
    end

    return item
  end

  function M.registerModules(moduleMap)
    modules = moduleMap or {}
  end

  function M.addAsyncSource(name, fn)
    -- Pass nil to remove a previously registered source
    asyncSources[name] = fn or nil
  end

  function M.calculatorItem(query)
    local normalized = helpers.normalizeText(query)
    if not normalized or not normalized:match("^[%d%s%+%-%*%/%(%)%.,]+$") then
      return nil
    end

    local expression = normalized:gsub(",", "")
    local chunk = load("return " .. expression, "calc", "t", {})
    if not chunk then
      return nil
    end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "number" then
      return nil
    end

    local id = "calc:" .. helpers.hashString(expression)
    local item = makeItem(id, "calculator", tostring(result), expression, "Calculator", {
      { id = "copy", label = "Copy Result", primary = true },
    })

    return {
      item = item,
      handlers = {
        [id] = function()
          hs.pasteboard.setContents(tostring(result))
          hs.alert.show("Copied result")
        end,
        [id .. ":copy"] = function()
          hs.pasteboard.setContents(tostring(result))
          hs.alert.show("Copied result")
        end,
      },
    }
  end

  function M.quickLinkItems(query)
    local entries = {}
    local links = config.quickLinks or {}

    for _, link in ipairs(links) do
      if helpers.matchQuery(query, link.title, link.url, link.keywords) then
        local id = "link:" .. helpers.hashString(link.url)
        table.insert(entries, {
          item = makeItem(id, "link", link.title, link.url, "Quick Link", {
            { id = "open", label = "Open", primary = true },
            { id = "copy", label = "Copy URL" },
          }),
          handlers = {
            [id] = function()
              hs.urlevent.openURL(link.url)
            end,
            [id .. ":open"] = function()
              hs.urlevent.openURL(link.url)
            end,
            [id .. ":copy"] = function()
              hs.pasteboard.setContents(link.url)
              hs.alert.show("Copied URL")
            end,
          },
        })
      end
    end

    return entries
  end

  function M.scoreItem(item, query, usage, recentRank)
    local score = 0
    usage = usage or loadUsage()
    recentRank = recentRank or {}

    score = score + (usage[item.id] or 0) * 8
    if recentRank[item.id] then
      score = score + (50 - recentRank[item.id])
    end

    if query == "" or not query then
      return score
    end

    local title = string.lower(item.title or "")
    local subtitle = string.lower(item.subtitle or "")
    local badge = string.lower(item.badge or "")
    local keywords = string.lower(item.keywords or item.searchText or "")
    local haystacks = { title, subtitle, badge, keywords }

    if title:sub(1, #query) == query then
      score = score + 400
    elseif title:find(query, 1, true) then
      score = score + 250
    end

    if subtitle:find(query, 1, true) then
      score = score + 120
    end
    if badge:find(query, 1, true) or keywords:find(query, 1, true) then
      score = score + 80
    end

    local terms = {}
    for term in query:gmatch("%S+") do
      table.insert(terms, term)
    end
    if #terms > 1 then
      local matchedTerms = 0
      for _, term in ipairs(terms) do
        for _, text in ipairs(haystacks) do
          if text:find(term, 1, true) then
            matchedTerms = matchedTerms + 1
            break
          end
        end
      end
      if matchedTerms == #terms then
        score = score + 180
      end
    end

    if item.kind == "calculator" or item.kind == "shell" then
      return score + 500
    end

    if score == 0 and query ~= "" then
      return -1
    end

    return score
  end

  function M.rankItems(items, query)
    local usage = loadUsage()
    local recent = loadRecent()
    local recentRank = {}
    for index, id in ipairs(recent) do
      recentRank[id] = index
    end

    local q = string.lower(query or "")

    table.sort(items, function(left, right)
      local leftScore = M.scoreItem(left, q, usage, recentRank)
      local rightScore = M.scoreItem(right, q, usage, recentRank)
      if leftScore ~= rightScore then
        return leftScore > rightScore
      end
      return (left.rank or 0) < (right.rank or 0)
    end)

    if q ~= "" then
      local filtered = {}
      for _, item in ipairs(items) do
        if M.scoreItem(item, q, usage, recentRank) >= 0 then
          table.insert(filtered, item)
        end
      end
      items = filtered
    end

    return items
  end

  function M.buildSync(query)
    local items = {}
    local handlers = {}
    local rank = 0

    local function registerItem(item, moduleHandlers)
      rank = rank + 1
      item.rank = rank
      table.insert(items, item)

      if moduleHandlers then
        for key, fn in pairs(moduleHandlers) do
          if key == item.id or key:sub(1, #item.id + 1) == item.id .. ":" then
            handlers[key] = fn
          end
        end
        if moduleHandlers[item.id] then
          handlers[item.id] = moduleHandlers[item.id]
        elseif item.actions and item.actions[1] then
          local primary = item.actions[1].id
          if moduleHandlers[item.id .. ":" .. primary] then
            handlers[item.id] = moduleHandlers[item.id .. ":" .. primary]
          end
        end
      end
    end

    for _, moduleInstance in pairs(modules) do
      if moduleInstance.indexContributions then
        local moduleItems, moduleHandlers = moduleInstance.indexContributions(query)
        for _, item in ipairs(moduleItems or {}) do
          registerItem(item, moduleHandlers)
        end
      end
    end

    local calc = M.calculatorItem(query)
    if calc then
      registerItem(calc.item, calc.handlers)
    end

    for _, entry in ipairs(M.quickLinkItems(query)) do
      registerItem(entry.item, entry.handlers)
    end

    items = M.rankItems(items, query)

    local limit = config.launcherResultLimit or 120
    if #items > limit then
      local trimmed = {}
      for index = 1, limit do
        trimmed[index] = items[index]
      end
      items = trimmed
    end

    local usage = loadUsage()
    for _, item in ipairs(items) do
      item.usageCount = usage[item.id] or 0
    end

    return items, handlers
  end

  local function dispatchFileSearch(normalized, onDone)
    local paths = config.searchRoots or {}
    if #paths == 0 then
      onDone({}, {})
      return
    end

    local onlyIn = {}
    for _, path in ipairs(paths) do
      table.insert(onlyIn, shellQuote(path))
    end
    local mdQuery = normalized:gsub('"', '\\"')
    local findPattern = normalized:gsub("([%*%?%[%]])", "\\%1")
    local cmd = string.format(
      "(mdfind -onlyin %s '(kMDItemFSName == \"*%s*\"cd)' 2>/dev/null; "
        .. "find %s -type f -iname '*%s*' 2>/dev/null) | awk 'NF && !seen[$0]++' | head -n %d",
      table.concat(onlyIn, " -onlyin "),
      mdQuery,
      table.concat(onlyIn, " "),
      findPattern,
      config.searchFileLimit or 20
    )

    hs.task.new("/bin/sh", function(_, stdout)
      local items = {}
      local handlers = {}
      local rank = 0

      for line in (stdout or ""):gmatch("[^\r\n]+") do
        if hs.fs.attributes(line) then
          rank = rank + 1
          local id = "file:" .. helpers.hashString(line)
          local name = line:match("([^/]+)$") or line
          local item = makeItem(id, "file", name, line, "File", {
            { id = "open", label = "Open", primary = true },
            { id = "reveal", label = "Reveal in Finder" },
            { id = "copy", label = "Copy Path" },
          }, { path = line, keywords = line })

          item.rank = 1000 + rank
          table.insert(items, item)
          handlers[id] = function()
            hs.execute(string.format("open %q", line))
          end
          handlers[id .. ":open"] = handlers[id]
          handlers[id .. ":reveal"] = function()
            hs.execute(string.format("open -R %q", line))
          end
          handlers[id .. ":copy"] = function()
            hs.pasteboard.setContents(line)
            hs.alert.show("Copied path")
          end
        end
      end

      onDone(items, handlers)
    end, { "-c", cmd }):start()
  end

  function M.buildAsync(query, callback)
    local normalized = helpers.normalizeText(query)
    if not normalized or #normalized < 2 then
      callback({}, {}, true)
      return
    end

    -- Count how many async sources we're dispatching (file search + registered sources)
    local extraSourceCount = 0
    for _ in pairs(asyncSources) do
      extraSourceCount = extraSourceCount + 1
    end
    local pending = 1 + extraSourceCount  -- 1 for file search

    local allItems = {}
    local allHandlers = {}
    local seenIds = {}

    local function onSourceDone(sourceItems, sourceHandlers)
      for _, item in ipairs(sourceItems or {}) do
        if not seenIds[item.id] then
          seenIds[item.id] = true
          table.insert(allItems, item)
        end
      end
      for key, fn in pairs(sourceHandlers or {}) do
        allHandlers[key] = fn
      end
      pending = pending - 1
      callback(allItems, allHandlers, pending == 0)
    end

    -- Dispatch built-in file search
    dispatchFileSearch(normalized, onSourceDone)

    -- Dispatch registered async sources in parallel
    for _, fn in pairs(asyncSources) do
      local ok, err = pcall(fn, query, onSourceDone)
      if not ok then
        hs.printf("async source error: %s", tostring(err))
        onSourceDone({}, {})
      end
    end
  end

  return M
end
