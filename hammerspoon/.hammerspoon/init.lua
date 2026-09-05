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
  if previousState.windowChooser then
    previousState.windowChooser:delete()
  end
  if previousState.windowSwitcher then
    previousState.windowSwitcher:delete()
  end
  if previousState.ghosttyWindowSwitcher then
    previousState.ghosttyWindowSwitcher:delete()
  end
  -- Clean up the former right Shift-to-Tab remap on the first reload.
  if previousState.rightShiftToTabTap then
    previousState.rightShiftToTabTap:stop()
    if previousState.rightShiftToTabDown then
      hs.eventtap.event.newKeyEvent({}, "tab", false):post()
    end
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

local function setSpaceIndicator(index)
  index = tonumber(index)
  if not index or index < 1 then
    return
  end

  state.spaceIndex = index
  if state.spaceMenu then
    state.spaceMenu:setTitle(styledSpaceTitle(index))
  end
end

local function refreshSpaceIndicator(showAlert)
  runYabai({ "-m", "query", "--spaces" }, function(ok, output)
    if not ok then return end

    local spaces = hs.json.decode(output) or {}
    for _, space in ipairs(spaces) do
      if space["has-focus"] then
        setSpaceIndicator(space.index)
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

bind({ "ctrl", "cmd" }, "n", function() refreshSpaceIndicator(true) end)

bind({ "alt" }, "f", function()
  hs.osascript.applescript([[tell application "Finder"
  make new Finder window to (get home)
  activate
end tell]])
end)

-- Ghostty 1.3.x can miss the initial appearance sync for hidden titlebar windows.
local function reloadGhosttyConfig(attempts)
  attempts = attempts or 0
  if attempts >= 30 then return end

  local app = hs.application.get("Ghostty")
  local window = app and app:mainWindow()
  if not window or not window:isVisible() then
    hs.timer.doAfter(0.1, function()
      reloadGhosttyConfig(attempts + 1)
    end)
    return
  end

  local reloaded = hs.osascript.applescript([[tell application "Ghostty"
    perform action "reload_config" on terminal 1 of front window
  end tell]])
  if not reloaded then
    hs.timer.doAfter(0.1, function()
      reloadGhosttyConfig(attempts + 1)
    end)
  end
end

bind({ "alt" }, "g", function()
  if hs.application.get("Ghostty") then
    hs.osascript.applescript([[
      tell application "Ghostty"
        new window
      end tell]])
  else
    hs.application.open("Ghostty", 2, true)
    hs.timer.doAfter(0.1, function()
      reloadGhosttyConfig()
    end)
  end
end)
