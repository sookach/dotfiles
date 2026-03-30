return {
  spec = 'https://github.com/nvim-mini/mini.icons',
  config = function()
    local ok, mini_icons = pcall(require, 'mini.icons')
    if ok then
      mini_icons.setup({ style = "glyph" })
      mini_icons.mock_nvim_web_devicons()
    end
  end
}