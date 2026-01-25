return {
  'NTBBloodbath/doom-one.nvim',
  config = function()
    vim.g.doom_one_cursor_coloring = true
    vim.g.doom_one_terminal_colors = true
    vim.g.doom_one_enable_treesitter = true
    vim.g.doom_one_plugin_barbar = true
    vim.g.doom_one_plugin_nvim_tree = true
    vim.cmd('colorscheme doom-one')
  end
}
