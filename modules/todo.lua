return function(config, helpers)
  local M = {}
  local refreshLauncher = nil

  local function loadTodos()
    helpers.ensureDir(config.dataDir)
    return helpers.readJsonFile(config.todoFile, {})
  end

  local function saveTodos(todos)
    helpers.ensureDir(config.dataDir)
    helpers.writeJsonFile(config.todoFile, todos)
  end

  local function sortTodos(todos)
    table.sort(todos, function(left, right)
      if left.done ~= right.done then
        return not left.done
      end
      return (left.updatedAt or 0) > (right.updatedAt or 0)
    end)
  end

  function M.setRefreshHandler(fn)
    refreshLauncher = fn
  end

  local function afterChange()
    if refreshLauncher then
      refreshLauncher()
    end
  end

  function M.addTodo(text)
    local normalized = helpers.normalizeText(text)
    if not normalized then
      hs.alert.show("TODO cannot be empty")
      return false
    end

    local todos = loadTodos()
    table.insert(todos, 1, {
      id = tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999)),
      text = normalized,
      done = false,
      updatedAt = os.time(),
    })
    saveTodos(todos)
    hs.alert.show("TODO saved")
    afterChange()
    return true
  end

  function M.indexContributions(query)
    local items = {}
    local handlers = {}
    local todos = loadTodos()
    sortTodos(todos)
    local normalizedQuery = helpers.normalizeText(query)
    local likelyTaskText = normalizedQuery
      and (
        normalizedQuery:find("%s")
        or normalizedQuery:find("[\128-\255]")
        or normalizedQuery:match("^todo%s+")
      )
    local shouldOfferCreate = normalizedQuery
      and #normalizedQuery >= 2
      and likelyTaskText
      and not normalizedQuery:match("^!")
      and not normalizedQuery:match("^sh%s+")
      and not normalizedQuery:match("^shell%s+")
      and not normalizedQuery:match("^[%d%s%+%-%*%/%(%)%.,]+$")

    if shouldOfferCreate then
      local addId = "todo:add:" .. helpers.hashString(normalizedQuery)
      table.insert(items, {
        id = addId,
        kind = "todo",
        title = "Add: " .. normalizedQuery,
        subtitle = "Create a new task",
        badge = "TODO",
        accent = helpers.accentForId(addId),
        keywords = normalizedQuery,
        actions = {
          { id = "open", label = "Add Task", primary = true },
        },
      })
      handlers[addId] = function()
        M.addTodo(normalizedQuery)
      end
      handlers[addId .. ":open"] = handlers[addId]
    end

    for _, todo in ipairs(todos) do
      local label = (todo.done and "[Done] " or "[Todo] ") .. todo.text
      if helpers.matchQuery(query, label, todo.text, "todo task") then
        local id = "todo:" .. todo.id
        table.insert(items, {
          id = id,
          kind = "todo",
          title = label,
          subtitle = todo.done and "Completed task" or "Open task",
          badge = "TODO",
          accent = helpers.accentForId(id),
          keywords = todo.text,
          actions = {
            { id = "toggle", label = todo.done and "Mark Todo" or "Mark Done", primary = true },
            { id = "copy", label = "Copy Text" },
            { id = "delete", label = "Delete" },
          },
        })

        handlers[id] = function()
          todo.done = not todo.done
          todo.updatedAt = os.time()
          saveTodos(todos)
          hs.alert.show(todo.done and "Marked done" or "Marked todo")
          afterChange()
        end
        handlers[id .. ":toggle"] = handlers[id]
        handlers[id .. ":copy"] = function()
          hs.pasteboard.setContents(todo.text)
          hs.alert.show("Copied")
        end
        handlers[id .. ":delete"] = function()
          for index, item in ipairs(todos) do
            if item.id == todo.id then
              table.remove(todos, index)
              break
            end
          end
          saveTodos(todos)
          hs.alert.show("Deleted TODO")
          afterChange()
        end
      end
    end

    return items, handlers
  end

  function M.launcherCommands()
    return {}
  end

  return M
end
