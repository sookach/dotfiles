return {
  spec = 'https://github.com/nvim-tree/nvim-tree.lua',
  config = function()
    local ok, nvim_tree = pcall(require, 'nvim-tree')
    if ok then
      nvim_tree.setup({
        tab = { sync = { open = true, close = true } }
      })
      vim.keymap.set('n', '<leader>t', '<cmd>NvimTreeToggle<cr>')
    end
  end
}