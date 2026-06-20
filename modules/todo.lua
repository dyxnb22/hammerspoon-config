return function(config, helpers)
  local M = {}

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

  local function openTodoActions(todo, todos)
    helpers.chooseFromList("TODO action", {
      {
        text = todo.done and "Mark As Todo" or "Mark As Done",
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
    }, function(choice)
      if choice.action == "toggle" then
        todo.done = not todo.done
        todo.updatedAt = os.time()
        saveTodos(todos)
        hs.alert.show(todo.done and "Marked done" or "Marked todo")
        return
      end

      if choice.action == "delete" then
        for index, item in ipairs(todos) do
          if item.id == todo.id then
            table.remove(todos, index)
            break
          end
        end
        saveTodos(todos)
        hs.alert.show("Deleted TODO")
        return
      end

      if choice.action == "copy" then
        hs.pasteboard.setContents(todo.text)
        hs.alert.show("Copied")
      end
    end)
  end

  function M.openChooser()
    local todos = loadTodos()
    sortTodos(todos)

    local choices = {
      {
        text = "Add TODO",
        subText = "Create a new task",
        action = "add",
      },
    }

    for _, todo in ipairs(todos) do
      table.insert(choices, {
        text = (todo.done and "[Done] " or "[Todo] ") .. todo.text,
        subText = todo.done and "Completed task" or "Active task",
        action = "todo",
        todoId = todo.id,
      })
    end

    helpers.chooseFromList("TODO", choices, function(choice)
      if choice.action == "add" then
        local seedText = helpers.textFromSelectionOrClipboard() or ""
        local button, value = hs.dialog.textPrompt("New TODO", "Task name", seedText, "Save", "Cancel")
        if button ~= "Save" then
          return
        end

        local text = helpers.normalizeText(value)
        if not text then
          hs.alert.show("TODO cannot be empty")
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
        return
      end

      for _, todo in ipairs(todos) do
        if todo.id == choice.todoId then
          openTodoActions(todo, todos)
          return
        end
      end
    end)
  end

  return M
end
