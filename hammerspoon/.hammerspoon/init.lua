require("hs.ipc")
hs = hs
hs.menuIcon(true)

local previousState = rawget(_G, "_dotfilesHammerspoonState")
if previousState then
  if previousState.spaceWatcher then
    previousState.spaceWatcher:stop()
  end
  if previousState.spaceMenu then
    previousState.spaceMenu:delete()
  end
  if previousState.vimMenu then
    previousState.vimMenu:delete()
  end
end

local state = {}
_G._dotfilesHammerspoonState = state

local yabai = "/opt/homebrew/bin/yabai"
local spaceFont = "NotoSansM Nerd Font Mono"
local vimMode = previousState and previousState.vimMode or "insert"

hs.alert.defaultStyle.textFont = spaceFont

local function styledSpaceTitle(index)
  return hs.styledtext.new(tostring(index), {
    font = { name = spaceFont, size = 12 },
  })
end

local function styledVimTitle(mode)
  return hs.styledtext.new(string.upper(string.sub(mode, 1, 1)),
    { font = { name = spaceFont, size = 12 }, }
  )
end

local function setVimMode(mode)
  if mode ~= "normal" and mode ~= "insert" and mode ~= "visual" then
    hs.printf("unknown Vim mode: %s", tostring(mode))
    return
  end

  vimMode = mode
  state.vimMode = mode
  if state.vimMenu then
    state.vimMenu:setTitle(styledVimTitle(mode))
  end
end

_G._dotfilesSetVimMode = setVimMode

local function runYabai(args, callback)
  local task = hs.task.new(yabai, function(exitCode, stdout, stderr)
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

  if not task:start() then
    hs.printf("could not start yabai task")
    return false
  end

  return true
end

local function setSpaceIndicator(index)
  index = tonumber(index)
  if not index or index < 1 then
    return
  end

  if state.spaceMenu then
    state.spaceMenu:setTitle(styledSpaceTitle(index))
  end
end

local function refreshSpaceIndicator()
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

state.vimMenu = hs.menubar.new()
if state.vimMenu then
  state.vimMenu:setTitle(styledVimTitle(vimMode))
  state.vimMenu:setTooltip("Vim mode")
end
state.vimMode = vimMode

state.spaceWatcher = hs.spaces.watcher.new(function(index)
  if index and index > 0 then
    setSpaceIndicator(index)
  else
    refreshSpaceIndicator()
  end
end)
state.spaceWatcher:start()
refreshSpaceIndicator()
