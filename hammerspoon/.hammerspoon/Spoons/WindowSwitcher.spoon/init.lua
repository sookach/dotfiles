local obj = {}
obj.__index = obj

obj.name = "WindowSwitcher"
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

local function htmlEncodedJSON(value)
  local encoded = hs.json.encode(value)
  encoded = encoded:gsub("&", "\\u0026")
  encoded = encoded:gsub("<", "\\u003c")
  encoded = encoded:gsub(">", "\\u003e")
  return encoded
end

local function windowSwitcherHTML(choices)
  local choicesJSON = htmlEncodedJSON(choices)
  return [[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
:root {
  color-scheme: dark;
}

html, body {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
}

body {
  box-sizing: border-box;
  padding: 10px;
  background: transparent;
  color: #f5f7fb;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
}

.panel {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 22px;
  background: rgba(30, 33, 42, 0.68);
  box-shadow: 0 24px 70px rgba(0, 0, 0, 0.42), inset 0 1px rgba(255, 255, 255, 0.1);
  -webkit-backdrop-filter: blur(30px) saturate(170%);
  backdrop-filter: blur(30px) saturate(170%);
}

.search {
  padding: 18px 18px 12px;
}

#query {
  box-sizing: border-box;
  width: 100%;
  padding: 11px 13px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 12px;
  outline: none;
  background: rgba(255, 255, 255, 0.09);
  color: #ffffff;
  font: 16px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  caret-color: #a9c4ff;
}

#query::placeholder {
  color: rgba(245, 247, 251, 0.48);
}

#query:focus {
  border-color: rgba(169, 196, 255, 0.72);
  box-shadow: 0 0 0 3px rgba(120, 157, 255, 0.16);
}

.results {
  min-height: 0;
  overflow-y: auto;
  padding: 2px 10px 12px;
}

.results::-webkit-scrollbar {
  width: 8px;
}

.results::-webkit-scrollbar-thumb {
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.2);
}

.row {
  box-sizing: border-box;
  display: block;
  width: 100%;
  margin: 2px 0;
  padding: 10px 12px;
  border: 1px solid transparent;
  border-radius: 11px;
  outline: none;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
}

.row.selected {
  border-color: rgba(180, 201, 255, 0.2);
  background: linear-gradient(100deg, rgba(126, 157, 255, 0.27), rgba(103, 118, 177, 0.14));
}

.title, .meta {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.title {
  font-size: 14px;
  line-height: 20px;
}

.meta {
  margin-top: 2px;
  color: rgba(245, 247, 251, 0.56);
  font-size: 11px;
  line-height: 16px;
}

.empty {
  padding: 18px 12px;
  color: rgba(245, 247, 251, 0.56);
  font-size: 13px;
}
</style>
</head>
<body>
<div class="panel">
  <div class="search">
    <input id="query" type="text" autofocus placeholder="Switch to window" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
  </div>
  <div id="results" class="results" role="listbox"></div>
</div>
<script>
const choices = ]] .. choicesJSON .. [[;
const queryField = document.getElementById("query");
const results = document.getElementById("results");
let matches = [];
let selectedIndex = 0;

function fuzzyScore(value, query) {
  const candidate = String(value || "").toLocaleLowerCase();
  const needle = String(query || "").toLocaleLowerCase();
  let score = 0;
  let previousMatch = -1;

  for (const character of needle) {
    const match = candidate.indexOf(character, previousMatch + 1);
    if (match === -1) return null;

    if (match === previousMatch + 1) score += 10;
    if (match === 0 || /[\s\W]/.test(candidate[match - 1])) score += 20;
    score -= match + 1;
    previousMatch = match;
  }

  return score;
}

function send(message) {
  try {
    window.webkit.messageHandlers.dotfilesWindowSwitcher.postMessage(message);
  } catch (error) {
    // The webview may be closing while a key event is being processed.
  }
}

function filterChoices() {
  const query = queryField.value;
  if (query === "") return choices.slice();

  return choices
    .map((choice) => {
      const textScore = fuzzyScore(choice.text, query);
      const metaScore = fuzzyScore(choice.subText, query);
      const score = metaScore !== null && (textScore === null || metaScore > textScore)
        ? metaScore
        : textScore;
      return { choice, score };
    })
    .filter((match) => match.score !== null)
    .sort((left, right) => {
      if (left.score !== right.score) return right.score - left.score;
      return left.choice.text.localeCompare(right.choice.text);
    })
    .map((match) => match.choice);
}

function updateSelection() {
  Array.from(results.children).forEach((row, index) => {
    const selected = index === selectedIndex;
    row.classList.toggle("selected", selected);
    row.setAttribute("aria-selected", selected ? "true" : "false");
  });

  const selectedRow = results.children[selectedIndex];
  if (selectedRow) selectedRow.scrollIntoView({ block: "nearest" });
}

function choose(index) {
  const choice = matches[index === undefined ? selectedIndex : index];
  if (choice) send({ type: "select", id: String(choice.id) });
}

function render() {
  matches = filterChoices();
  selectedIndex = matches.length === 0 ? -1 : Math.min(Math.max(selectedIndex, 0), matches.length - 1);
  results.textContent = "";

  if (matches.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = "No matching windows";
    results.appendChild(empty);
    return;
  }

  matches.forEach((choice, index) => {
    const row = document.createElement("div");
    row.className = "row";
    row.setAttribute("role", "option");

    const title = document.createElement("div");
    title.className = "title";
    title.textContent = choice.text;

    const meta = document.createElement("div");
    meta.className = "meta";
    meta.textContent = choice.subText;

    row.appendChild(title);
    row.appendChild(meta);
    row.addEventListener("mouseenter", () => {
      selectedIndex = index;
      updateSelection();
    });
    row.addEventListener("mousedown", (event) => {
      event.preventDefault();
      choose(index);
    });
    results.appendChild(row);
  });

  updateSelection();
}

queryField.addEventListener("input", () => {
  selectedIndex = 0;
  render();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "ArrowDown") {
    event.preventDefault();
    if (matches.length > 0) selectedIndex = (selectedIndex + 1) % matches.length;
    updateSelection();
  } else if (event.key === "ArrowUp") {
    event.preventDefault();
    if (matches.length > 0) selectedIndex = (selectedIndex - 1 + matches.length) % matches.length;
    updateSelection();
  } else if (event.key === "Enter") {
    event.preventDefault();
    choose();
  } else if (event.key === "Escape") {
    event.preventDefault();
    send({ type: "cancel" });
  }
});

render();
queryField.focus();
</script>
</body>
</html>]]
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

function obj:hide()
  if self.window and self.window:isVisible() then
    self.window:hide()
  end
end

function obj:handleMessage(message)
  local event = message and message.body
  if type(event) ~= "table" then return end

  if event.type == "cancel" then
    self:hide()
    return
  end

  if event.type ~= "select" then return end
  local windowID = tonumber(event.id)
  self:hide()
  if not windowID then return end

  self:runYabai({ "-m", "window", tostring(windowID), "--focus" }, function(ok, stdout, stderr)
    if not ok then
      local message = stderr ~= "" and stderr or stdout
      hs.alert.show("Could not focus window: " .. (message ~= "" and message or "unknown error"), 1.2)
    end
  end)
end

function obj:init()
  self.activeTasks = {}
  self.controller = hs.webview.usercontent.new("dotfilesWindowSwitcher")
  self.controller:setCallback(function(message)
    self:handleMessage(message)
  end)

  self.window = hs.webview.new(
    switcherFrame(),
    { javaScriptEnabled = true },
    self.controller
  )
  self.window
    :allowTextEntry(true)
    :transparent(true)
    :windowStyle(0)
    :darkMode(true)
    :shadow(false)
    :level(hs.drawing.windowLevels.floating)
    :behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
  self.window:windowCallback(function(action, _, focused)
    if action == "focusChange" and not focused then
      self:hide()
    end
  end)
end

function obj:show()
  if not self.window then return end

  self:runYabai({ "-m", "query", "--windows" }, function(ok, output, stderr)
    if not ok then
      local message = stderr ~= "" and stderr or "could not query windows"
      hs.alert.show("Could not list windows: " .. message, 1.2)
      return
    end

    local windows = hs.json.decode(output) or {}
    local choices = {}
    for _, window in ipairs(windows) do
      if window.id and window["has-ax-reference"] then
        local app = window.app or "Unknown application"
        local title = window.title or ""
        local subText = app
        if window.space then
          subText = subText .. "  |  Space " .. tostring(window.space)
        end

        choices[#choices + 1] = {
          text = title ~= "" and title or app,
          subText = subText,
          id = window.id,
        }
      end
    end

    if #choices == 0 then
      hs.alert.show("No windows found", 0.8)
      return
    end

    local view = self.window
    view:frame(switcherFrame())
    view:html(windowSwitcherHTML(choices))
    view:show()
    hs.timer.doAfter(0.05, function()
      if view:isVisible() then
        view:evaluateJavaScript("document.getElementById('query').focus()")
      end
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

function obj:delete()
  if self.hotkey then
    self.hotkey:delete()
    self.hotkey = nil
  end
  if self.controller then
    self.controller:setCallback(nil)
  end
  if self.window then
    self.window:delete()
    self.window = nil
  end
  self.controller = nil
  self.activeTasks = {}
end

return obj
