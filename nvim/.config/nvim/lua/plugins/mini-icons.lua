return {
  "nvim-mini/mini.icons",
  event = "VeryLazy",
  opts = {
    style = "glyph",
  },
  config = function(_, opts)
    local mini_icons = require("mini.icons")
    mini_icons.setup(opts)
    -- Mock nvim-web-devicons API for compatibility with plugins like fzf-lua
    mini_icons.mock_nvim_web_devicons()
  end,
}