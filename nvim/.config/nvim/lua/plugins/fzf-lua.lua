return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    { '<leader>ff', '<cmd>FzfLua files<cr>',                mode = 'n' },
    { '<leader>fs', '<cmd>FzfLua live_grep<cr>',            mode = 'n' },
    { '<leader>fd', '<cmd>FzfLua diagnostics_document<cr>', mode = 'n' }
  }
}
