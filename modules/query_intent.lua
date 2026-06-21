-- Query Intent Router: classify a search query and provide group budgets.
-- This is a pure-Lua module (no factory pattern, no hs.* calls) so it can be
-- unit-tested outside a running Hammerspoon instance.

local M = {}

-- CJK code-point ratio in text
local function cjkRatio(text)
  if not text or #text == 0 then return 0 end
  local total, cjk = 0, 0
  for _, code in utf8.codes(text) do
    total = total + 1
    if (code >= 0x4E00 and code <= 0x9FFF)  -- CJK Unified Ideographs
      or (code >= 0x3400 and code <= 0x4DBF) -- CJK Extension A
      or (code >= 0x3040 and code <= 0x30FF) -- Hiragana + Katakana
      or (code >= 0xAC00 and code <= 0xD7AF) then -- Hangul
      cjk = cjk + 1
    end
  end
  return total > 0 and (cjk / total) or 0
end

local function wordCount(text)
  local n = 0
  for _ in (text or ""):gmatch("%S+") do n = n + 1 end
  return n
end

-- Intents and their meanings:
--   "empty"        query is blank
--   "short"        1-2 ASCII chars – extremely conservative
--   "calculator"   pure math expression
--   "shell"        ! / sh / shell prefix
--   "notes_recent" "recent note(s)" or "最近笔记"
--   "notes"        lone "note/notes/笔记"
--   "daily"        "daily/journal/today/日记"
--   "clipboard"    "clipboard/paste"
--   "translate"    "translate/tr .../翻译"
--   "todo_create"  "todo <text>" / "task <text>"
--   "file"         looks like a filename/path
--   "app"          single ASCII word ≥ 3 chars (app-like)
--   "sentence"     ≥ 3 words or mostly-CJK ≥ 4 chars
--   "generic"      everything else

function M.classify(query)
  local raw = (query or ""):match("^%s*(.-)%s*$") or ""
  if raw == "" then return "empty" end

  local lower = raw:lower()
  local len   = #raw
  local ratio = cjkRatio(raw)
  local isCJK = ratio >= 0.3

  -- Short but semantically explicit keywords that override the "short" budget
  if lower == "tr" then return "translate" end

  -- 1-2 ASCII chars: very conservative (includes "a", "d", "no")
  if len <= 2 and not isCJK then return "short" end

  -- Calculator: only digits, operators, parens, dots, spaces
  if lower:match("^[%d%s%+%-%*%/%(%)%.%%^,]+$") and lower:match("%d") then
    return "calculator"
  end

  -- Shell command prefixes
  if lower:match("^!%s+.") or lower:match("^sh%s+.") or lower:match("^shell%s+.") then
    return "shell"
  end

  -- Explicit translate (prefix match)
  if lower:match("^translat") or lower:match("^翻译") then
    return "translate"
  end

  -- Notes recent
  if (lower:find("recent", 1, true) and lower:find("note", 1, true))
    or lower:find("最近笔记", 1, true) then
    return "notes_recent"
  end

  -- Daily note
  if lower:match("^daily") or lower:match("^journal")
    or lower == "today" or lower == "日记" or lower == "今天" then
    return "daily"
  end

  -- Notes (lone keyword)
  if lower == "note" or lower == "notes" or lower == "笔记"
    or lower:match("^notes?%s") then
    return "notes"
  end

  -- Clipboard (paste / copy / clipboard)
  if lower == "clipboard" or lower == "paste" or lower == "copy" or lower:match("^clipb") then
    return "clipboard"
  end

  -- Explicit todo create: "todo <text>" / "task <text>"
  if lower:match("^todo%s+.") or lower:match("^task%s+.")
    or lower:match("^待办%s") then
    return "todo_create"
  end

  -- File-like: has a dotted extension or path separator
  if lower:match("%.%a%a%a?%a?$") or lower:find("/", 1, true) then
    return "file"
  end

  -- Sentence detection: ≥3 words, or mostly-CJK with ≥4 chars
  local wc = wordCount(raw)
  if wc >= 3 or (isCJK and len >= 4) then
    return "sentence"
  end

  -- Single ASCII word (≥3 chars, no spaces) → app-like
  if not lower:find("%s") and not isCJK then
    return "app"
  end

  return "generic"
end

-- Default per-kind item cap for each group in the results list
M.DEFAULT_BUDGETS = {
  app        = 8,
  window     = 6,
  file       = 6,
  note       = 8,
  todo       = 5,
  clipboard  = 4,
  snippet    = 3,
  command    = 5,
  system     = 3,
  shell      = 2,
  ai         = 3,
  link       = 4,
  calculator = 1,
}

-- Intent-specific overrides (merged on top of defaults).
-- A value of 0 means "hide entirely."
local INTENT_BUDGETS = {
  empty       = { clipboard = 3, todo = 3, note = 0, ai = 0, file = 0,
                  calculator = 0, link = 2, snippet = 2, app = 0 },
  short       = { clipboard = 0, todo = 0, note = 0, ai = 0, snippet = 0,
                  file = 0, calculator = 0, link = 0 },
  calculator  = { calculator = 1, ai = 0, clipboard = 0, todo = 0,
                  file = 0, note = 0, snippet = 0, link = 0 },
  shell       = { shell = 2, clipboard = 0, todo = 0, ai = 0,
                  note = 0, file = 0 },
  notes_recent= { note = 15, command = 3, clipboard = 0, ai = 0, todo = 0 },
  notes       = { note = 12, command = 4, clipboard = 0, ai = 0 },
  daily       = { note = 8,  command = 4, clipboard = 0, ai = 0 },
  clipboard   = { clipboard = 15, snippet = 5, note = 0, ai = 0, todo = 0 },
  todo_create = { todo = 12, command = 2, clipboard = 0, ai = 0 },
  translate   = { ai = 6, command = 3, clipboard = 0 },
  -- "app" intent: boost apps, suppress clipboard/AI/files, but keep notes
  -- because note titles can legitimately match app-like single words.
  app         = { app = 12, window = 6, file = 0, ai = 0, clipboard = 0 },
  file        = { file = 12, app = 4, ai = 0, clipboard = 0 },
  sentence    = { ai = 3, todo = 5, app = 6, window = 4,
                  note = 4, clipboard = 2 },
  generic     = {},
}

-- Return effective budgets for a classified intent
function M.budgetsFor(intent)
  local budgets = {}
  for k, v in pairs(M.DEFAULT_BUDGETS) do budgets[k] = v end
  for k, v in pairs(INTENT_BUDGETS[intent] or {}) do budgets[k] = v end
  return budgets
end

return M
