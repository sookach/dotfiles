return {
  spec = 'https://github.com/nvim-mini/mini.icons',
  config = function()
    local mini_icons = require('mini.icons')
    mini_icons.setup { style = "glyph" }
    mini_icons.mock_nvim_web_devicons()
  end
}

