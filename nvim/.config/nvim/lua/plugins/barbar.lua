return {
  spec = 'https://github.com/romgrk/barbar.nvim',
  config = function()
    local ok, barbar = pcall(require, 'barbar')
    if ok then barbar.setup() end
  end
}