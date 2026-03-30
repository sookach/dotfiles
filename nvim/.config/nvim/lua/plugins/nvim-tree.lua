return {
  spec = 'https://github.com/nvim-tree/nvim-tree.lua',
  config = function()
    local nvim_tree = require('nvim-tree')
    nvim_tree.setup {
      tab = { sync = { open = true, close = true } }
    }
    vim.keymap.set('n', '<leader>t', '<cmd>NvimTreeToggle<cr>')
  end
}

