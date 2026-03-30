return {
  spec = 'https://github.com/nvim-lualine/lualine.nvim',
  config = function()
    local ok, lualine = pcall(require, 'lualine')
    if ok then lualine.setup() end
  end
}