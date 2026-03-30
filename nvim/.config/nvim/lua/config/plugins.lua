local specs = {}
local configs = {}

-- Discover all files in the lua/plugins directory
local plugin_files = vim.fn.glob(vim.fn.stdpath("config") .. "/lua/plugins/*.lua", true, true)

for _, file in ipairs(plugin_files) do
  local name = vim.fn.fnamemodify(file, ":t:r")
  local mod = require("plugins." .. name)

  if type(mod) == "table" then
    if mod.spec then
      -- If spec is a list of strings (array), unpack them
      if type(mod.spec) == "table" and mod.spec[1] then
        for _, s in ipairs(mod.spec) do
          table.insert(specs, s)
        end
      else
        -- It's a single string or a specific table like { src = '...', version = '...' }
        table.insert(specs, mod.spec)
      end
    end

    if mod.config then
      table.insert(configs, mod.config)
    end
  end
end

-- Add all gathered specs to the package manager at once
vim.pack.add(specs)

-- Safely run all configuration blocks
for _, cfg in ipairs(configs) do
  cfg()
end
