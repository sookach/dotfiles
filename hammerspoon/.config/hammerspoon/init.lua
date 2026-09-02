require("hs.ipc")

local previousState = rawget(_G, "_dotfilesHammerspoonState")
if previousState then
  if previousState.spaceInputTap then
    previousState.spaceInputTap:stop()
  end
  if previousState.spaceInputAlert then
    hs.alert.closeSpecific(previousState.spaceInputAlert, 0)
  end
  if previousState.spaceWatcher then
    previousState.spaceWatcher:stop()
  end
  if previousState.spaceMenu then
    previousState.spaceMenu:delete()
  end
end

local state = {}
_G._dotfilesHammerspoonState = state

local yabai = "/opt/homebrew/bin/yabai"
local activeTasks = {}
local spaceFont = "NotoSansM Nerd Font Mono"

hs.alert.defaultStyle.textFont = spaceFont

local function styledSpaceTitle(index)
  return hs.styledtext.new(tostring(index), {
    font = { name = spaceFont, size = 12 },
  })
end

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

local function spaceList()
  return hs.spaces.spacesForScreen(hs.screen.mainScreen()) or {}
end

local function setSpaceIndicator(index, showAlert)
  index = tonumber(index)
  if not index or index < 1 then
    return
  end

  state.spaceIndex = index
  if state.spaceMenu then
    state.spaceMenu:setTitle(styledSpaceTitle(index))
  end
  if showAlert then
    hs.alert.show(" " .. index .. " ", 0.7)
  end
end

local function refreshSpaceIndicator(showAlert)
  runYabai({ "-m", "query", "--spaces" }, function(ok, output)
    if not ok then return end

    local spaces = hs.json.decode(output) or {}
    for _, space in ipairs(spaces) do
      if space["has-focus"] then
        setSpaceIndicator(space.index, showAlert)
        return
      end
    end
  end)
end

state.spaceMenu = hs.menubar.new()
if state.spaceMenu then
  state.spaceMenu:setTitle(styledSpaceTitle("?"))
  state.spaceMenu:setTooltip("Current Space")
end

state.spaceWatcher = hs.spaces.watcher.new(function(index)
  if index and index > 0 then
    setSpaceIndicator(index)
  else
    refreshSpaceIndicator()
  end
end)
state.spaceWatcher:start()
refreshSpaceIndicator()

local function ensureSpace(index, onReady)
  if state.spaceOperation then
    hs.alert.show("Space operation already in progress", 0.8)
    return
  end

  if #spaceList() >= index then
    if onReady then onReady() end
    return
  end

  state.spaceOperation = true

  local function finish(ok, err)
    state.spaceOperation = false
    if not ok then
      hs.alert.show("Could not create Space: " .. tostring(err or "unknown error"), 1.2)
      return
    end
    if onReady then onReady() end
  end

  local function addNext()
    local spaces = spaceList()
    if #spaces >= index then
      finish(true)
      return
    end

    local closeMissionControl = #spaces + 1 >= index
    local ok, err = hs.spaces.addSpaceToScreen(
      hs.screen.mainScreen(),
      closeMissionControl
    )
    if not ok then
      finish(false, err)
      return
    end

    hs.timer.doAfter(0.35, addNext)
  end

  addNext()
end

local function focusOrCreateSpace(index)
  local focus = function()
    runYabai({ "-m", "space", "--focus", tostring(index) })
  end

  if #spaceList() >= index then
    focus()
    return
  end

  ensureSpace(index, focus)
end

local digitKeys = {}
for digit = 0, 9 do
  local key = tostring(digit)
  digitKeys[hs.keycodes.map[key]] = key
end

local function stopSpaceInput()
  if state.spaceInputTap then
    state.spaceInputTap:stop()
    state.spaceInputTap = nil
  end
  if state.spaceInputAlert then
    hs.alert.closeSpecific(state.spaceInputAlert, 0)
    state.spaceInputAlert = nil
  end
  state.spaceInputDigits = nil
end

local function updateSpaceInput()
  if state.spaceInputAlert then
    hs.alert.closeSpecific(state.spaceInputAlert, 0)
  end

  local digits = state.spaceInputDigits ~= "" and state.spaceInputDigits or "_"
  state.spaceInputAlert = hs.alert.show(digits, 3600)
end

local function beginSpaceInput()
  if state.spaceInputTap then return end

  state.spaceInputDigits = ""
  updateSpaceInput()

  state.spaceInputTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local keycode = event:getKeyCode()
    local digit = digitKeys[keycode]
    if digit then
      state.spaceInputDigits = state.spaceInputDigits .. digit
      updateSpaceInput()
      return true
    end

    if keycode == hs.keycodes.map["return"] then
      local target = tonumber(state.spaceInputDigits)
      stopSpaceInput()
      if target and target > 0 then
        focusOrCreateSpace(target)
      else
        hs.alert.show("No Space number entered", 0.7)
      end
      return true
    end

    stopSpaceInput()
    return true
  end)
  state.spaceInputTap:start()
end

bind({ "ctrl", "cmd" }, "s", beginSpaceInput)

local function closeWindowsInSpace(spaceIndex, callback, attempts)
  attempts = attempts or 0
  if attempts >= 100 then
    callback(false, "too many windows to close")
    return
  end

  runYabai({ "-m", "query", "--windows" }, function(ok, output, stderr)
    if not ok then
      callback(false, stderr ~= "" and stderr or "could not query windows")
      return
    end

    local windows = hs.json.decode(output) or {}
    local windowToClose
    for _, window in ipairs(windows) do
      if window.space == spaceIndex then
        windowToClose = window
        break
      end
    end

    if not windowToClose then
      callback(true)
      return
    end

    runYabai({ "-m", "window", tostring(windowToClose.id), "--close" }, function(closed, stdout, closeError)
      if not closed then
        local message = closeError ~= "" and closeError or stdout
        callback(false, message ~= "" and message or ("could not close window " .. windowToClose.id))
        return
      end

      hs.timer.doAfter(0.1, function()
        closeWindowsInSpace(spaceIndex, callback, attempts + 1)
      end)
    end)
  end)
end

local function focusSpaceWithYabai(spaceID, callback)
  runYabai({ "-m", "query", "--spaces" }, function(ok, output, stderr)
    if not ok then
      callback(false, stderr)
      return
    end

    local spaces = hs.json.decode(output) or {}
    for _, space in ipairs(spaces) do
      if space.id == spaceID then
        runYabai({ "-m", "space", "--focus", tostring(space.index) }, function(focused, _, focusError)
          callback(focused, focusError)
        end)
        return
      end
    end

    callback(false, "could not find the target Space")
  end)
end

local function removeCurrentSpace()
  if state.spaceOperation then
    hs.alert.show("Space operation already in progress", 0.8)
    return
  end

  local spaces = spaceList()
  local current = hs.spaces.focusedSpace()
  local currentIndex
  for index, space in ipairs(spaces) do
    if space == current then
      currentIndex = index
      break
    end
  end

  if not currentIndex or hs.spaces.spaceType(current) ~= "user" then
    hs.alert.show("The current Space cannot be removed", 1)
    return
  end

  local destination = spaces[currentIndex - 1] or spaces[currentIndex + 1]
  if not destination then
    hs.alert.show("Cannot remove the only Space", 1)
    return
  end

  state.spaceOperation = true
  closeWindowsInSpace(currentIndex, function(closed, closeError)
    if not closed then
      state.spaceOperation = false
      hs.alert.show("Could not close all windows: " .. tostring(closeError or "unknown error"), 1.2)
      return
    end

    focusSpaceWithYabai(destination, function(moved, moveError)
      if not moved then
        state.spaceOperation = false
        hs.alert.show("Could not switch Space: " .. tostring(moveError or "unknown error"), 1.2)
        return
      end

      local function removeWhenFocused(attempts)
        if hs.spaces.focusedSpace() ~= destination then
          if attempts == 0 then
            state.spaceOperation = false
            hs.alert.show("Could not switch to the neighboring Space", 1.2)
            return
          end
          hs.timer.doAfter(0.05, function() removeWhenFocused(attempts - 1) end)
          return
        end

        local removed, removeError = hs.spaces.removeSpace(current)
        if not removed then
          state.spaceOperation = false
          hs.alert.show("Could not remove Space: " .. tostring(removeError or "unknown error"), 1.2)
          return
        end

        hs.timer.doAfter((hs.spaces.MCwaitTime or 0.3) + 0.1, function()
          state.spaceOperation = false
          refreshSpaceIndicator()
        end)
      end

      removeWhenFocused(20)
    end)
  end)
end

bind({ "ctrl", "cmd" }, "n", function() refreshSpaceIndicator(true) end)
bind({ "ctrl", "cmd" }, "d", removeCurrentSpace)

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

-- Vim-style navigation in macOS text fields.
local VimMode = hs.loadSpoon("VimMode")
local vim = VimMode:new()
vim:bindHotKeys({
  enter = { { "ctrl", "cmd" }, "a" },
})
