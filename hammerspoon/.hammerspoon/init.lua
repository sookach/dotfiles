require("hs.ipc")

local previousState = rawget(_G, "_dotfilesHammerspoonState")
if previousState then
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
local spaceFont = "NotoSansM Nerd Font Mono"

hs.alert.defaultStyle.textFont = spaceFont

local function styledSpaceTitle(index)
  return hs.styledtext.new(tostring(index), {
    font = { name = spaceFont, size = 12 },
  })
end

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

state.spaceWatcher = hs.spaces.watcher.new(function(index)
  if index and index > 0 then
    setSpaceIndicator(index)
  else
    refreshSpaceIndicator()
  end
end)
state.spaceWatcher:start()
refreshSpaceIndicator()
