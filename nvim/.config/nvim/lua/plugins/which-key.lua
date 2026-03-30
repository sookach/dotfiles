return {
  spec = 'https://github.com/folke/which-key.nvim',
  config = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
    local ok, wk = pcall(require, 'which-key')
    if ok then
      wk.setup({
        plugins = { spelling = true },
        colors = true,
      })
    end
  end
}