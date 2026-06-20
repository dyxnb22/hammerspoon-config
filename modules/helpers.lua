local json = hs.json

local M = {}

function M.readFile(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()
  return content
end

function M.readJsonFile(path, fallback)
  local content = M.readFile(path)
  if not content or content == "" then
    return fallback
  end

  local ok, decoded = pcall(json.decode, content)
  if ok and decoded ~= nil then
    return decoded
  end

  return fallback
end

function M.writeJsonFile(path, value)
  local file = assert(io.open(path, "w"))
  file:write(json.encode(value, true))
  file:close()
end

function M.normalizeText(text)
  if type(text) ~= "string" then
    return nil
  end

  local normalized = text:gsub("^%s+", ""):gsub("%s+$", "")
  if normalized == "" then
    return nil
  end

  return normalized
end

function M.previewText(text, maxLength)
  local normalized = M.normalizeText(text)
  if not normalized then
    return ""
  end

  local oneLine = normalized:gsub("%s+", " ")
  if #oneLine <= maxLength then
    return oneLine
  end

  return oneLine:sub(1, maxLength - 1) .. "..."
end

function M.matchQuery(query, ...)
  local normalizedQuery = string.lower(query or "")
  if normalizedQuery == "" then
    return true
  end

  for _, part in ipairs({ ... }) do
    if part and string.find(string.lower(part), normalizedQuery, 1, true) then
      return true
    end
  end

  return false
end

function M.safeIcon(app)
  local ok, image = pcall(function()
    return app:icon()
  end)

  if ok then
    return image
  end

  return nil
end

function M.ensureDir(path)
  hs.fs.mkdir(path)
end

function M.chooseFromList(title, choices, callback)
  local chooser = hs.chooser.new(function(choice)
    if choice and callback then
      callback(choice)
    end
  end)

  chooser:searchSubText(true)
  chooser:placeholderText(title)
  chooser:choices(choices)
  chooser:show()
end

function M.textFromSelectionOrClipboard()
  local selectedText = nil
  local element = hs.uielement.focusedElement()

  if element then
    local ok, value = pcall(function()
      return element:selectedText()
    end)

    if ok then
      selectedText = M.normalizeText(value)
    end
  end

  if selectedText then
    return selectedText
  end

  return M.normalizeText(hs.pasteboard.getContents())
end

return M
