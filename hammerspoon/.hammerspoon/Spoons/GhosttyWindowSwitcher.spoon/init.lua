local obj = {}
obj.__index = obj

obj.name = "GhosttyWindowSwitcher"
obj.version = "1.0"
obj.author = "sookach"
obj.license = "MIT"
obj.homepage = "https://github.com/sookach/dotfiles"
obj.yabai = "/opt/homebrew/bin/yabai"

local function switcherFrame()
  local screenFrame = hs.screen.mainScreen():frame()
  local width = math.min(760, screenFrame.w - 48)
  local height = math.min(520, screenFrame.h - 48)

  return {
    x = screenFrame.x + (screenFrame.w - width) / 2,
    y = screenFrame.y + (screenFrame.h - height) / 2,
    w = width,
    h = height,
  }
end

local function windowIDsByApp(windows, app)
  local ids = {}
  for _, window in ipairs(windows) do
    if window.app == app then
      ids[window.id] = true
    end
  end
  return ids
end

function obj:runYabai(args, callback)
  local task
  task = hs.task.new(self.yabai, function(exitCode, stdout, stderr)
    self.activeTasks[task] = nil

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

  self.activeTasks[task] = true
  if not task:start() then
    self.activeTasks[task] = nil
    hs.printf("could not start yabai task")
    return false
  end

  return true
end

function obj:restorePreviousWindow(closeSwitcher)
  local previousID = self.previousID
  local switcherID = self.switcherID
  self.previousID = nil
  self.previousSpace = nil
  self.switcherID = nil
  self.launching = false

  local close = function()
    if closeSwitcher and switcherID then
      self:runYabai({ "-m", "window", tostring(switcherID), "--close" })
    end
  end

  if previousID then
    self:runYabai({ "-m", "window", tostring(previousID), "--focus" }, function()
      close()
    end)
  else
    close()
  end
end

function obj:abort(message)
  if message then
    hs.alert.show(message, 1.2)
  end
  self:restorePreviousWindow(true)
end

function obj:runPicker()
  local previousID = self.previousID
  local switcherID = self.switcherID
  if not previousID or not switcherID then
    self:abort("Could not start the window picker")
    return
  end

  local scriptPath = self.spoonPath .. "switcher.zsh"
  local command = string.format("exec /bin/zsh %q %d %d", scriptPath, previousID, switcherID)
  local window = hs.window.get(switcherID)
  if window then
    window:focus()
  end

  hs.timer.doAfter(0.15, function()
    if self.switcherID ~= switcherID then return end
    hs.eventtap.keyStrokes(command)
    hs.eventtap.keyStroke({}, "return")
  end)
  self:watchSwitcher(switcherID)
end

function obj:watchSwitcher(windowID)
  if self.switcherID ~= windowID then return end

  self:runYabai({ "-m", "query", "--windows" }, function(ok, output)
    if ok then
      local windows = hs.json.decode(output) or {}
      for _, window in ipairs(windows) do
        if window.id == windowID then
          hs.timer.doAfter(0.2, function()
            self:watchSwitcher(windowID)
          end)
          return
        end
      end

      self.switcherID = nil
      self.previousID = nil
    else
      hs.timer.doAfter(0.2, function()
        self:watchSwitcher(windowID)
      end)
    end
  end)
end

function obj:prepareSwitcher(windowID)
  self.switcherID = windowID
  self.launching = false

  local floatSwitcher = function()
    self:runYabai({ "-m", "window", tostring(windowID), "--toggle", "float" }, function(ok, _, stderr)
      if not ok then
        self:abort(stderr ~= "" and stderr or "Could not make Ghostty floating")
        return
      end

      self:runYabai({ "-m", "window", tostring(windowID), "--focus" }, function(focused, _, focusError)
        if not focused then
          self:abort(focusError ~= "" and focusError or "Could not focus the Ghostty picker")
          return
        end

        local window = hs.window.get(windowID)
        if window then
          window:setFrame(switcherFrame())
        end
        self:runPicker()
      end)
    end)
  end

  if self.previousSpace then
    self:runYabai({ "-m", "window", tostring(windowID), "--space", tostring(self.previousSpace) },
      function(ok, _, stderr)
        if not ok then
          self:abort(stderr ~= "" and stderr or "Could not move the Ghostty picker")
          return
        end
        floatSwitcher()
      end)
    return
  end

  floatSwitcher()
end

function obj:findNewGhosttyWindow(existingIDs, attempts)
  if not self.launching then return end

  self:runYabai({ "-m", "query", "--windows" }, function(ok, output)
    if ok then
      local windows = hs.json.decode(output) or {}
      for _, window in ipairs(windows) do
        if window.app == "Ghostty" and not existingIDs[window.id] then
          self:prepareSwitcher(window.id)
          return
        end
      end
    end

    if attempts >= 30 then
      self:abort("Could not find the Ghostty picker window")
      return
    end

    hs.timer.doAfter(0.1, function()
      self:findNewGhosttyWindow(existingIDs, attempts + 1)
    end)
  end)
end

function obj:show()
  if self.launching or self.switcherID then return end

  self:runYabai({ "-m", "query", "--windows", "--window" }, function(ok, output, stderr)
    if not ok then
      hs.alert.show("Could not find the focused window: " .. stderr, 1.2)
      return
    end

    local focused = hs.json.decode(output)
    if not focused or not focused.id then
      hs.alert.show("Could not find the focused window", 1.2)
      return
    end
    self.previousID = focused.id
    self.previousSpace = focused.space

    self:runYabai({ "-m", "query", "--windows" }, function(queried, windowsOutput, queryError)
      if not queried then
        self:abort(queryError ~= "" and queryError or "Could not list Ghostty windows")
        return
      end

      local windows = hs.json.decode(windowsOutput) or {}
      local existingIDs = windowIDsByApp(windows, "Ghostty")
      self.launching = true

      local launched = hs.osascript.applescript([[tell application "Ghostty"
        new window
        activate
      end tell]])
      if not launched then
        self:abort("Could not open a Ghostty window")
        return
      end

      self:findNewGhosttyWindow(existingIDs, 0)
    end)
  end)
end

function obj:bindHotkey(modifiers, key)
  if self.hotkey then
    self.hotkey:delete()
  end

  self.hotkey = hs.hotkey.bind(modifiers, key, function()
    self:show()
  end)
  return self
end

function obj:init()
  self.activeTasks = {}
  self.launching = false
  self.previousID = nil
  self.previousSpace = nil
  self.switcherID = nil
end

function obj:delete()
  if self.hotkey then
    self.hotkey:delete()
    self.hotkey = nil
  end

  if self.switcherID or self.launching then
    self:restorePreviousWindow(true)
  end
  self.activeTasks = {}
end

return obj
