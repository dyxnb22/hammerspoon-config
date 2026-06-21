return function(_, helpers)
  local M = {}
  local json = hs.json

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

  local function showResult(source, translated)
    helpers.chooseFromList("Translation", {
      {
        text = translated,
        subText = "Copied to clipboard",
        action = "copy",
      },
      {
        text = source,
        subText = "Original text",
        action = "noop",
      },
    }, function(choice)
      if choice.action == "copy" then
        hs.pasteboard.setContents(translated)
      end
    end)
  end

  function M.translateText(text)
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
        hs.urlevent.openURL("https://translate.google.com/?sl=auto&tl=" .. target .. "&text=" .. hs.http.encodeForQuery(normalized) .. "&op=translate")
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

      hs.pasteboard.setContents(result)
      hs.alert.show("Translated and copied")
      showResult(normalized, result)
    end)
  end

  function M.prompt()
    local defaultText = helpers.textFromSelectionOrClipboard() or ""
    local button, text = hs.dialog.textPrompt(
      "Google Translate",
      "Translate the selected text or edit it first",
      defaultText,
      "Translate",
      "Cancel"
    )

    if button == "Translate" then
      M.translateText(text)
    end
  end

  function M.launcherCommands()
    return {
      {
        id = "translate",
        text = "Google Translate",
        subText = "Translate selected text or clipboard text",
        run = M.prompt,
      },
    }
  end

  return M
end
