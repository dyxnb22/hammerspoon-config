return function(config, helpers)
  local M = {}

  local chooser = nil

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

  local function buildChoices(query)
    local todos = loadTodos()
    sortTodos(todos)

    local choices = {}
    local normalizedQuery = helpers.normalizeText(query)

    if normalizedQuery then
      table.insert(choices, {
        text = "Add: " .. normalizedQuery,
        subText = "Press Enter to create this task",
        action = "add",
        value = normalizedQuery,
      })
    else
      table.insert(choices, {
        text = "Type above to add a new task",
        subText = "Enter creates the task from the search box",
        action = "noop",
      })
    end

    for _, todo in ipairs(todos) do
      table.insert(choices, {
        text = (todo.done and "[Done] " or "[Todo] ") .. todo.text,
        subText = todo.done and "Enter reopens · choose to toggle/delete/copy" or "Enter reopens · choose to toggle/delete/copy",
        action = "todo",
        todoId = todo.id,
      })
    end

    return choices, todos
  end

  local function handleTodoChoice(choice, todos)
    if choice.action == "add" then
      local text = helpers.normalizeText(choice.value)
      if not text then
        hs.alert.show("TODO cannot be empty")
        M.openChooser(choice.query)
        return
      end

      table.insert(todos, 1, {
        id = tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999)),
        text = text,
        done = false,
        updatedAt = os.time(),
      })
      saveTodos(todos)
      hs.alert.show("TODO saved")
      M.openChooser("")
      return
    end

    if choice.action ~= "todo" then
      return
    end

    local selected = nil
    for _, todo in ipairs(todos) do
      if todo.id == choice.todoId then
        selected = todo
        break
      end
    end

    if not selected then
      return
    end

    helpers.chooseFromList("TODO action", {
      {
        text = selected.done and "Mark As Todo" or "Mark As Done",
        subText = "Toggle this task status",
        action = "toggle",
      },
      {
        text = "Delete TODO",
        subText = "Remove this task permanently",
        action = "delete",
      },
      {
        text = "Copy TODO Text",
        subText = "Copy task text to clipboard",
        action = "copy",
      },
    }, function(actionChoice)
      if actionChoice.action == "toggle" then
        selected.done = not selected.done
        selected.updatedAt = os.time()
        saveTodos(todos)
        hs.alert.show(selected.done and "Marked done" or "Marked todo")
      elseif actionChoice.action == "delete" then
        for index, item in ipairs(todos) do
          if item.id == selected.id then
            table.remove(todos, index)
            break
          end
        end
        saveTodos(todos)
        hs.alert.show("Deleted TODO")
      elseif actionChoice.action == "copy" then
        hs.pasteboard.setContents(selected.text)
        hs.alert.show("Copied")
      end

      M.openChooser("")
    end)
  end

  function M.openChooser(seedQuery)
    if not chooser then
      chooser = hs.chooser.new(function(choice)
        if not choice then
          return
        end

        local query = chooser:query()
        local _, todos = buildChoices(query)
        choice.query = query

        if choice.action == "noop" then
          M.openChooser(query)
          return
        end

        handleTodoChoice(choice, todos)
      end)

      chooser:searchSubText(true)
      chooser:placeholderText("TODO")
      chooser:queryChangedCallback(function()
        local query = chooser:query()
        chooser:choices(buildChoices(query))
      end)
    end

    chooser:choices(buildChoices(seedQuery or ""))
    if seedQuery then
      chooser:query(seedQuery)
    end
    chooser:show()
  end

  function M.launcherCommands()
    return {
      {
        id = "todo",
        text = "TODO",
        subText = "Capture, toggle, and clean up tasks",
        run = function()
          M.openChooser(helpers.textFromSelectionOrClipboard() or "")
        end,
      },
    }
  end

  return M
end
