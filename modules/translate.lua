return function(_, helpers)
  local M = {}
  local json = hs.json
  local refreshLauncher = nil
  local lastResult = nil

  function M.setRefreshHandler(fn)
    refreshLauncher = fn
  end

  local function cjkRatio(text)
    local total = 0
    local cjk = 0

    for _, code in utf8.codes(text) do
      total = total + 1
      if (code >= 0x4E00 and code <= 0x9FFF)
        or (code >= 0x3400 and code <= 0x4DBF)
        or (code >= 0x3040 and code <= 0x30FF)
        or (code >= 0xAC00 and code <= 0xD7AF) then
        cjk = cjk + 1
      end
    end

    if total == 0 then
      return 0
    end

    return cjk / total
  end

  local function detectTargetLanguage(text)
    if cjkRatio(text) >= 0.2 then
      return "en"
    end
    return "zh-CN"
  end

  function M.translateText(text, options)
    options = options or {}
    local normalized = helpers.normalizeText(text)
    if not normalized then
      hs.alert.show("No text to translate")
      return
    end

    local target = detectTargetLanguage(normalized)
    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl="
      .. target
      .. "&dt=t&q="
      .. hs.http.encodeForQuery(normalized)

    hs.http.asyncGet(url, nil, function(status, body)
      if status ~= 200 then
        hs.urlevent.openURL(
          "https://translate.google.com/?sl=auto&tl="
            .. target
            .. "&text="
            .. hs.http.encodeForQuery(normalized)
            .. "&op=translate"
        )
        hs.alert.show("Opened Google Translate in browser")
        return
      end

      local ok, decoded = pcall(json.decode, body)
      if not ok or type(decoded) ~= "table" or type(decoded[1]) ~= "table" then
        hs.alert.show("Translation failed")
        return
      end

      local translated = {}
      for _, segment in ipairs(decoded[1]) do
        if type(segment) == "table" and segment[1] then
          table.insert(translated, segment[1])
        end
      end

      local result = table.concat(translated, "")
      if result == "" then
        hs.alert.show("Translation failed")
        return
      end

      lastResult = {
        source = normalized,
        translated = result,
        target = target,
      }

      if options.copy ~= false then
        hs.pasteboard.setContents(result)
        hs.alert.show("Translated and copied")
      end

      if refreshLauncher then
        refreshLauncher()
      end
    end)
  end

  function M.indexContributions(query)
    local items = {}
    local handlers = {}
    local normalizedQuery = helpers.normalizeText(query)
    local explicitTranslate = helpers.matchQuery(query, "translate", "tr", "翻译")
    local sentenceLike = normalizedQuery
      and #normalizedQuery >= 4
      and (normalizedQuery:find("%s") or cjkRatio(normalizedQuery) >= 0.2)

    if normalizedQuery and #normalizedQuery >= 2 and (explicitTranslate or sentenceLike) then
      local id = "translate:query:" .. helpers.hashString(normalizedQuery)
      table.insert(items, {
          id = id,
        kind = "ai",
        title = "Translate: " .. helpers.previewText(normalizedQuery, 48),
        subtitle = "Google Translate",
        badge = "Translate",
        accent = helpers.accentForId(id),
        keywords = "translate tr " .. normalizedQuery,
        actions = {
          { id = "run", label = "Translate", primary = true },
        },
      })
      handlers[id] = function()
        M.translateText(normalizedQuery)
      end
      handlers[id .. ":run"] = handlers[id]
    end

    local selection = nil
    local ok, value = pcall(helpers.textFromSelectionOrClipboard)
    if ok then
      selection = value
    end

    if selection and (not normalizedQuery or normalizedQuery == "") then
      local id = "translate:selection"
      table.insert(items, {
        id = id,
        kind = "ai",
        title = "Translate Selection",
        subtitle = helpers.previewText(selection, 60),
        badge = "Translate",
        accent = helpers.accentForId(id),
        keywords = "translate selection clipboard " .. selection,
        actions = {
          { id = "run", label = "Translate", primary = true },
        },
      })
      handlers[id] = function()
        M.translateText(selection)
      end
      handlers[id .. ":run"] = handlers[id]
    end

    if lastResult then
      local id = "translate:last"
      table.insert(items, {
        id = id,
        kind = "ai",
        title = helpers.previewText(lastResult.translated, 72),
        subtitle = "Last translation · " .. helpers.previewText(lastResult.source, 40),
        badge = "Translation",
        accent = helpers.accentForId(id),
        keywords = lastResult.source .. " " .. lastResult.translated,
        actions = {
          { id = "copy", label = "Copy Translation", primary = true },
          { id = "open", label = "Open in Browser" },
        },
      })
      handlers[id] = function()
        hs.pasteboard.setContents(lastResult.translated)
        hs.alert.show("Copied")
      end
      handlers[id .. ":copy"] = handlers[id]
      handlers[id .. ":open"] = function()
        hs.urlevent.openURL(
          "https://translate.google.com/?sl=auto&tl="
            .. (lastResult.target or "en")
            .. "&text="
            .. hs.http.encodeForQuery(lastResult.source)
            .. "&op=translate"
        )
      end
    end

    if explicitTranslate and not normalizedQuery then
      local id = "translate:hint"
      table.insert(items, {
        id = id,
        kind = "ai",
        title = "Type text to translate",
        subtitle = "Or select text before opening launcher",
        badge = "Translate",
        accent = helpers.accentForId(id),
        keywords = "translate tr",
        actions = {
          { id = "open", label = "Info", primary = true },
        },
      })
      handlers[id] = function()
        hs.alert.show("Type text in the search box to translate")
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  return M
end
