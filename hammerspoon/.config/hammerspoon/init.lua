require("hs.ipc")

local yabai = "/opt/homebrew/bin/yabai"
local activeTasks = {}

local function runYabai(args, callback)
  local task
  task = hs.task.new(yabai, function(exitCode, stdout, stderr)
    activeTasks[task] = nil

    local ok = exitCode == 0
    if not ok then
      hs.printf("yabai failed (%d): %s", exitCode, stderr ~= "" and stderr or stdout)
    end

    if callback then
      callback(ok, stdout, stderr)
    end
  end, args)

  if not task then
    hs.printf("could not start yabai task")
    return false
  end

  activeTasks[task] = true
  if not task:start() then
    activeTasks[task] = nil
    hs.printf("could not start yabai task")
    return false
  end

  return true
end

local function bind(modifiers, key, action)
  hs.hotkey.bind(modifiers, key, action)
end

local function resizeFocused(delta)
  runYabai({ "-m", "query", "--windows", "--window" }, function(ok, output)
    if not ok then return end

    local window = hs.json.decode(output)
    if not window or not window["split-child"] then return end

    if window["split-child"] ~= "first_child" then
      delta = -delta
    end

    runYabai({ "-m", "window", "--ratio", string.format("rel:%0.2f", delta) })
  end)
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
  hs.osascript.applescript([[tell application "Finder"
  make new Finder window to (get home)
  activate
end tell]])
end)
bind({ "alt" }, "g", function()
  hs.osascript.applescript([[tell application "Ghostty"
  new window
  activate
end tell]])
end)
bind({ "alt" }, "s", function()
  hs.osascript.applescript([[tell application "Safari"
  make new document at end of documents
  activate
end tell]])
end)

local function closeFocusedWindow()
  local closeWindow = function(focusWindow)
    runYabai({ "-m", "window", "--close" }, function(closed)
      if closed and focusWindow then
        runYabai({ "-m", "window", tostring(focusWindow), "--focus" })
      end
    end)
  end

  runYabai({ "-m", "query", "--windows", "--window" }, function(ok, output)
    if not ok then
      closeWindow()
      return
    end

    local focused = hs.json.decode(output)
    if not focused or not focused.id or not focused.space then
      closeWindow()
      return
    end

    runYabai({ "-m", "query", "--windows", "--space", tostring(focused.space) }, function(ok, output)
      local focusWindow
      if ok then
        local windows = hs.json.decode(output) or {}
        for _, window in ipairs(windows) do
          if window.id ~= focused.id
              and window["is-visible"]
              and not window["is-minimized"]
              and not window["is-hidden"] then
            focusWindow = window.id
            break
          end
        end
      end

      closeWindow(focusWindow)
    end)
  end)
end

bind({ "ctrl", "cmd" }, "w", closeFocusedWindow)
