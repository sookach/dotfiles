return {
  spec = 'https://github.com/folke/which-key.nvim',
  config = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
    local wk = require('which-key')
    wk.setup {
      plugins = { spelling = true },
      colors = true,
    }
  end
}

