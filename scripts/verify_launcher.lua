#!/usr/bin/env lua
-- Verification harness for launcher index layer (run via: hs -c "dofile('...')")

local repo = os.getenv("HOME") .. "/hammerspoon-config"
package.path = repo .. "/modules/?.lua;" .. repo .. "/?.lua;" .. package.path

local failures = {}

local function fail(message)
  table.insert(failures, message)
  print("FAIL: " .. message)
end

local function ok(message)
  print("OK: " .. message)
end

local config = require("config")
local helpers = require("helpers")
local searchIndex = require("search_index")(config, helpers)

local mockModules = {
  {
    indexContributions = function(query)
      return {
        {
          id = "test:one",
          kind = "command",
          title = "Alpha Command",
          subtitle = "demo",
          badge = "Command",
          keywords = "alpha",
          actions = { { id = "open", label = "Open", primary = true } },
        },
      },
      {
        ["test:one"] = function() end,
        ["test:one:open"] = function() end,
      }
    end,
  },
}

searchIndex.registerModules({ mock = mockModules[1] })

local items, handlers = searchIndex.buildSync("")
if #items < 1 then
  fail("buildSync returned no items")
else
  ok("buildSync returns items")
end

if not handlers["test:one"] then
  fail("handler map missing primary action")
else
  ok("handler map wired")
end

local ranked = searchIndex.buildSync("alpha")
if #ranked < 1 or ranked[1].id ~= "test:one" then
  fail("ranking did not prioritize alpha match")
else
  ok("prefix ranking works")
end

local calc = searchIndex.calculatorItem("2+2")
if not calc or calc.item.title ~= "4" then
  fail("calculator item missing")
else
  ok("calculator evaluates")
end

local score = searchIndex.scoreItem({ id = "x", title = "Translate", subtitle = "" }, "trans", {}, {})
if score < 0 then
  fail("scoreItem should match substring")
else
  ok("scoreItem substring match")
end

if #failures > 0 then
  print(string.format("\n%d failure(s)", #failures))
  os.exit(1)
end

print("\nAll launcher verification checks passed")
