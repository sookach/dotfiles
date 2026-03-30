return {
  spec = 'https://github.com/folke/trouble.nvim',
  config = function()
    local trouble = require('trouble')
    trouble.setup()
    vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = "Diagnostics (Trouble)" })
  end
}

