return {
  spec = 'https://github.com/folke/trouble.nvim',
  config = function()
    local ok, trouble = pcall(require, 'trouble')
    if ok then
      trouble.setup()
      vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = "Diagnostics (Trouble)" })
    end
  end
}