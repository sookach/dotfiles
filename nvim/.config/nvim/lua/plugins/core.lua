return {
  spec = {
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/nvim-tree/nvim-web-devicons',
    'https://github.com/MunifTanjim/nui.nvim',
    'https://github.com/rcarriga/nvim-notify',
    'https://github.com/rafamadriz/friendly-snippets',
    'https://github.com/lewis6991/gitsigns.nvim',
  },
  config = function()
    local gitsigns = require('gitsigns')
    gitsigns.setup()
  end
}
