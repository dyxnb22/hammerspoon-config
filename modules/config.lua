local repoRoot = os.getenv("HOME") .. "/hammerspoon-config"

return {
  repoRoot = repoRoot,
  assetsDir = repoRoot .. "/assets",
  docsDir = repoRoot .. "/docs",
  dataDir = hs.configdir,
  todoFile = hs.configdir .. "/todos.json",
  clipboardLimit = 80,
  hyper = { "ctrl", "alt", "cmd" },
  entryHotkey = { modifiers = { "cmd", "shift" }, key = "space" },
  units = {
    left = { x = 0, y = 0, w = 0.5, h = 1 },
    right = { x = 0.5, y = 0, w = 0.5, h = 1 },
    top = { x = 0, y = 0, w = 1, h = 0.5 },
    bottom = { x = 0, y = 0.5, w = 1, h = 0.5 },
    max = { x = 0, y = 0, w = 1, h = 1 },
    center = { x = 0.15, y = 0.1, w = 0.7, h = 0.8 },
  },
}
