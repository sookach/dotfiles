require("hs.ipc")

local yabai = "/opt/homebrew/bin/yabai"

local function runYabai(args)
  local output, ok, kind, code = hs.execute(yabai .. " " .. table.concat(args, " "), true)
  if not ok then
    hs.printf("yabai failed (%s %s): %s", kind, code, output)
  end
  return ok, output
end

local function bind(modifiers, key, action)
  hs.hotkey.bind(modifiers, key, action)
end

local function resizeFocused(delta)
  local ok, output = runYabai({ "-m", "query", "--windows", "--window" })
  if not ok then return end

  local window = hs.json.decode(output)
  if not window or not window["split-child"] then return end

  if window["split-child"] ~= "first_child" then
    delta = -delta
  end

  runYabai({ "-m", "window", "--ratio", string.format("rel:%0.2f", delta) })
end

local directions = {
  h = "west",
  j = "south",
  k = "north",
  l = "east",
}

for key, direction in pairs(directions) do
  bind({ "ctrl", "cmd" }, key, function()
    runYabai({ "-m", "window", "--focus", direction })
  end)
end

local warpDirections = {
  u = "west",
  i = "south",
  o = "north",
  p = "east",
}

for key, direction in pairs(warpDirections) do
  bind({ "ctrl", "cmd" }, key, function()
    runYabai({ "-m", "window", "--warp", direction })
  end)
end

bind({ "ctrl", "cmd" }, "m", function() runYabai({ "-m", "window", "--insert", "west" }) end)
bind({ "ctrl", "cmd" }, ",", function() runYabai({ "-m", "window", "--insert", "south" }) end)
bind({ "ctrl", "cmd" }, ".", function() runYabai({ "-m", "window", "--insert", "north" }) end)
bind({ "ctrl", "cmd" }, "/", function() runYabai({ "-m", "window", "--insert", "east" }) end)

bind({ "alt" }, ".", function() runYabai({ "-m", "window", "--toggle", "float" }) end)
bind({ "alt" }, "/", function() runYabai({ "-m", "window", "--toggle", "zoom-fullscreen" }) end)

bind({ "ctrl", "cmd" }, "-", function() resizeFocused(-0.03) end)
bind({ "ctrl", "cmd" }, "=", function() resizeFocused(0.03) end)
bind({ "ctrl", "cmd" }, "f", function() runYabai({ "-m", "window", "--toggle", "zoom-fullscreen" }) end)

for index = 1, 9 do
  local space = tostring(index)
  bind({ "alt" }, space, function() runYabai({ "-m", "space", "--focus", space }) end)
  bind({ "alt", "shift" }, space, function() runYabai({ "-m", "window", "--space", space }) end)
end

bind({ "ctrl", "cmd" }, ";", function() runYabai({ "-m", "space", "--focus", "prev" }) end)
bind({ "ctrl", "cmd" }, "'", function() runYabai({ "-m", "space", "--focus", "next" }) end)
bind({ "alt" }, "z", function() runYabai({ "-m", "space", "--focus", "prev" }) end)
bind({ "alt" }, "x", function() runYabai({ "-m", "space", "--focus", "next" }) end)
bind({ "alt", "shift" }, ";", function() runYabai({ "-m", "window", "--space", "prev" }) end)
bind({ "alt", "shift" }, "'", function() runYabai({ "-m", "window", "--space", "next" }) end)

bind({ "alt" }, "f", function()
  hs.osascript.applescript('tell application "Finder" to make new Finder window to (get home)')
end)
bind({ "alt" }, "g", function() hs.application.launchOrFocus("Ghostty") end)
bind({ "alt" }, "s", function()
  hs.osascript.applescript('tell application "Safari" to make new document at end of documents')
end)
bind({ "ctrl", "cmd" }, "w", function() runYabai({ "-m", "window", "--close" }) end)
