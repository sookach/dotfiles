return {
  spec = { src = 'https://github.com/nvim-treesitter/nvim-treesitter', branch = 'master' },
  config = function()
    local configs = require('nvim-treesitter.configs')
    configs.setup {
      highlight = { enable = true },
      ensure_installed = { "lua", "vim", "vimdoc", "query" },
    }

    vim.api.nvim_create_autocmd("User", {
      pattern = "PackChanged",
      callback = function()
        vim.cmd("TSUpdate")
      end,
    })
  end
}

