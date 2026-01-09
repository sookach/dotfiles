vim.opt.termguicolors = true
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.clipboard = "unnamedplus"

vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set({ 'n', 'v' }, 'gf', function()
  local conform_filetypes = {
    python = true,
    sh = true,
  }
  if conform_filetypes[vim.bo.filetype] then
    require("conform").format()
  else
    vim.lsp.buf.format()
  end
end)
vim.keymap.set('n', 'grd', vim.lsp.buf.declaration)
vim.keymap.set('n', 'grf', vim.lsp.buf.definition)
vim.keymap.set('n', '<c-w>u', '<cmd>tabprevious<cr>')
vim.keymap.set('n', '<c-w>i', '<cmd>tabnext<cr>')
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)

require("config.lazy")

vim.lsp.enable('luals')
vim.lsp.enable('clangd')
vim.lsp.enable('nixd')
vim.lsp.enable('zuban')
vim.lsp.enable('bashls')
vim.lsp.enable('gopls')
