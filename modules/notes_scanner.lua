return function(config, helpers)
  local M = {}

  local function vaultRoot()
    return config.notes.vaultPath
  end

  local function relativePath(absolutePath)
    local root = vaultRoot()
    if absolutePath:sub(1, #root) == root then
      local relative = absolutePath:sub(#root + 1)
      return relative:gsub("^/", "")
    end
    return absolutePath
  end

  local function walkMarkdownFiles(root, visitor)
    if not root or not hs.fs.attributes(root) then
      return
    end

    for entry in hs.fs.dir(root) do
      if entry ~= "." and entry ~= ".." then
        local path = root .. "/" .. entry
        local attr = hs.fs.attributes(path)
        if attr then
          if attr.mode == "directory" then
            walkMarkdownFiles(path, visitor)
          elseif entry:lower():match("%.md$") then
            visitor(path, attr)
          end
        end
      end
    end
  end

  local function splitLines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    return lines
  end

  local function stripWrappingQuotes(value)
    if type(value) ~= "string" then
      return value
    end

    local unquoted = value:gsub('^["\']', "")
    unquoted = unquoted:gsub('["\']$', "")
    return unquoted
  end

  local function parseScalarList(value)
    local items = {}
    if not value then
      return items
    end

    if value:match("^%[") then
      for item in value:gmatch("%[([^%]]+)%]") do
        for part in item:gmatch("[^,%s]+") do
          part = stripWrappingQuotes(part)
          if part ~= "" then
            table.insert(items, part)
          end
        end
      end
      return items
    end

    for part in value:gmatch("[^,%s]+") do
      part = stripWrappingQuotes(part)
      if part ~= "" then
        table.insert(items, part)
      end
    end

    return items
  end

  local function parseFrontMatter(text)
    local normalizedText = (text or ""):gsub("\r\n", "\n")
    if normalizedText:sub(1, 4) ~= "---\n" then
      return {}, text
    end

    local closeStart, closeEnd = normalizedText:find("\n---\n", 5, true)
    if not closeStart then
      closeStart, closeEnd = normalizedText:find("\n---", 5, true)
      if closeStart ~= (#normalizedText - 3) then
        closeStart = nil
        closeEnd = nil
      end
    end

    if not closeStart then
      return {}, text
    end

    local frontBlock = normalizedText:sub(5, closeStart - 1)
    local rest = normalizedText:sub(closeEnd + 1)

    local meta = {}
    local currentListKey = nil

    for _, line in ipairs(splitLines(frontBlock)) do
      local listItem = line:match("^%s*-%s+(.+)$")
      if currentListKey and listItem then
        table.insert(meta[currentListKey], stripWrappingQuotes(listItem))
      else
        currentListKey = nil
        local separator = line:find(":", 1, true)
        local key = separator and line:sub(1, separator - 1):match("^%s*([%w_%-]+)%s*$") or nil
        local value = separator and line:sub(separator + 1):gsub("^%s*", "") or nil
        if key and value then
          key = key:lower()
          if value == "" or value:match("^%[") then
            meta[key] = parseScalarList(value)
            if #meta[key] == 0 then
              currentListKey = key
              meta[key] = {}
            end
          else
            meta[key] = stripWrappingQuotes(value)
          end
        end
      end
    end

    return meta, rest
  end

  local function normalizeTags(meta)
    local tags = {}
    local raw = meta.tags
    if type(raw) == "table" then
      for _, tag in ipairs(raw) do
        if tag ~= "" then
          table.insert(tags, tag)
        end
      end
    elseif type(raw) == "string" and raw ~= "" then
      for tag in raw:gmatch("[^,%s]+") do
        table.insert(tags, tag)
      end
    end
    return tags
  end

  local function firstHeading(text)
    for line in text:gmatch("[^\r\n]+") do
      local heading = line:match("^#%s+(.+)$")
      if heading then
        return helpers.normalizeText(heading)
      end
    end
    return nil
  end

  local function collectWikiLinks(text)
    local links = {}
    for target in text:gmatch("%[%[([^%]]+)%]%]") do
      local label, note = target:match("^(.-)|(.+)$")
      local value = note or label or target
      value = helpers.normalizeText(value)
      if value then
        table.insert(links, value)
      end
    end
    return links
  end

  local function collectMarkdownLinks(text)
    local links = {}

    for target in text:gmatch("%[[^%]]*%]%(([^%)]+)%)") do
      if target:match("%.md") or not target:match("^https?://") then
        local cleaned = target:gsub("#.*$", "")
        cleaned = helpers.normalizeText(cleaned)
        if cleaned then
          table.insert(links, cleaned)
        end
      end
    end

    return links
  end

  local function collectMetaLinks(meta, key)
    local links = {}
    local value = meta[key]
    if type(value) == "table" then
      for _, item in ipairs(value) do
        if item ~= "" then
          table.insert(links, item)
        end
      end
    elseif type(value) == "string" and value ~= "" then
      for item in value:gmatch("[^,%s]+") do
        table.insert(links, item)
      end
    end
    return links
  end

  local function basenameWithoutExt(path)
    local name = path:match("([^/]+)%.md$")
    return name or path
  end

  local function resolveLinkTarget(target, lookup)
    if lookup[target] then
      return lookup[target]
    end

    local withoutExt = target:gsub("%.md$", "")
    if lookup[withoutExt] then
      return lookup[withoutExt]
    end

    local lower = string.lower(target)
    if lookup[lower] then
      return lookup[lower]
    end

    local lowerNoExt = string.lower(withoutExt)
    if lookup[lowerNoExt] then
      return lookup[lowerNoExt]
    end

    return nil
  end

  local function parseFile(path, attr)
    local content = helpers.readFile(path) or ""
    local meta = {}
    local body = content

    do
      local normalizedText = content:gsub("\r\n", "\n")
      if normalizedText:sub(1, 4) == "---\n" then
        local closeStart, closeEnd = normalizedText:find("\n---\n", 5, true)
        if not closeStart then
          closeStart, closeEnd = normalizedText:find("\n---", 5, true)
          if closeStart ~= (#normalizedText - 3) then
            closeStart = nil
            closeEnd = nil
          end
        end

        if closeStart then
          local frontBlock = normalizedText:sub(5, closeStart - 1)
          body = normalizedText:sub(closeEnd + 1)
          local currentListKey = nil

          for _, line in ipairs(splitLines(frontBlock)) do
            local listItem = line:match("^%s*-%s+(.+)$")
            if currentListKey and listItem then
              table.insert(meta[currentListKey], stripWrappingQuotes(listItem))
            else
              currentListKey = nil
              local separator = line:find(":", 1, true)
              local key = separator and line:sub(1, separator - 1):match("^%s*([%w_%-]+)%s*$") or nil
              local value = separator and line:sub(separator + 1):gsub("^%s*", "") or nil
              if key and value then
                key = key:lower()
                if value == "" or value:match("^%[") then
                  meta[key] = parseScalarList(value)
                  if #meta[key] == 0 then
                    currentListKey = key
                    meta[key] = {}
                  end
                else
                  meta[key] = stripWrappingQuotes(value)
                end
              end
            end
          end
        end
      end
    end

    local rel = relativePath(path)
    local fileName = path:match("([^/]+)$")
    local heading = firstHeading(body)
    local title = helpers.normalizeText(meta.title) or heading or basenameWithoutExt(path)
    local tags = normalizeTags(meta)

    return {
      id = rel,
      title = title,
      path = path,
      relPath = rel,
      fileName = fileName,
      folder = rel:match("(.+)/[^/]+$") or "",
      tags = tags,
      heading = heading,
      excerpt = helpers.previewText(body, 160),
      mtime = attr.modification or os.time(),
      parent = meta.parent,
      links = collectMetaLinks(meta, "links"),
      related = collectMetaLinks(meta, "related"),
      wikiLinks = collectWikiLinks(body),
      markdownLinks = collectMarkdownLinks(body),
    }
  end

  function M.scan()
    local root = vaultRoot()
    helpers.ensureDir(root)

    local parsed = {}
    walkMarkdownFiles(root, function(path, attr)
      table.insert(parsed, parseFile(path, attr))
    end)

    table.sort(parsed, function(left, right)
      return left.relPath < right.relPath
    end)

    local lookup = {}
    for _, node in ipairs(parsed) do
      lookup[node.id] = node.id
      lookup[node.relPath] = node.id
      lookup[node.fileName] = node.id
      lookup[basenameWithoutExt(node.relPath)] = node.id
      lookup[string.lower(node.id)] = node.id
      lookup[string.lower(node.fileName)] = node.id
      lookup[string.lower(basenameWithoutExt(node.relPath))] = node.id
      lookup[node.title] = node.id
      lookup[string.lower(node.title)] = node.id
    end

    local edges = {}
    local edgeKeys = {}

    local function addEdge(fromId, toId, edgeType)
      if not fromId or not toId or fromId == toId then
        return
      end
      local key = fromId .. "->" .. toId .. ":" .. edgeType
      if edgeKeys[key] then
        return
      end
      edgeKeys[key] = true
      table.insert(edges, { from = fromId, to = toId, type = edgeType })
    end

    for _, node in ipairs(parsed) do
      if node.parent then
        local parentId = resolveLinkTarget(node.parent, lookup)
        if parentId then
          addEdge(parentId, node.id, "parent")
        end
      end

      for _, link in ipairs(node.links) do
        local targetId = resolveLinkTarget(link, lookup)
        if targetId then
          addEdge(node.id, targetId, "link")
          addEdge(targetId, node.id, "link")
        end
      end

      for _, link in ipairs(node.related) do
        local targetId = resolveLinkTarget(link, lookup)
        if targetId then
          addEdge(node.id, targetId, "related")
          addEdge(targetId, node.id, "related")
        end
      end

      for _, link in ipairs(node.wikiLinks) do
        local targetId = resolveLinkTarget(link, lookup)
        if targetId then
          addEdge(node.id, targetId, "wiki")
          addEdge(targetId, node.id, "wiki")
        end
      end

      for _, link in ipairs(node.markdownLinks) do
        local targetId = resolveLinkTarget(link, lookup)
        if targetId then
          addEdge(node.id, targetId, "markdown")
        end
      end
    end

    local tags = {}
    for _, node in ipairs(parsed) do
      for _, tag in ipairs(node.tags) do
        tags[tag] = tags[tag] or {}
        table.insert(tags[tag], node.id)
      end
    end

    local recent = {}
    for _, node in ipairs(parsed) do
      table.insert(recent, {
        id = node.id,
        title = node.title,
        path = node.path,
        mtime = node.mtime,
      })
    end

    table.sort(recent, function(left, right)
      return left.mtime > right.mtime
    end)

    local nodes = {}
    for _, node in ipairs(parsed) do
      table.insert(nodes, {
        id = node.id,
        title = node.title,
        path = node.path,
        relPath = node.relPath,
        fileName = node.fileName,
        folder = node.folder,
        tags = node.tags,
        heading = node.heading,
        excerpt = node.excerpt,
        mtime = node.mtime,
      })
    end

    return {
      vault = root,
      scannedAt = os.time(),
      nodes = nodes,
      edges = edges,
      tags = tags,
      recent = recent,
    }
  end

  function M.saveIndex(index)
    helpers.ensureDir(config.dataDir)
    helpers.writeJsonFile(config.notes.indexFile, index)
    return index
  end

  function M.loadIndex()
    return helpers.readJsonFile(config.notes.indexFile, {
      vault = vaultRoot(),
      scannedAt = 0,
      nodes = {},
      edges = {},
      tags = {},
      recent = {},
    })
  end

  function M.refresh()
    local index = M.scan()
    M.saveIndex(index)
    return index
  end

  return M
end
