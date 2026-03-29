 return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    plugins = { spelling = true },
    -- Use mini.icons highlights when available
    colors = true,
    -- Modern spec format - all mappings defined here
    defaults = {},
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)
  end,
}
