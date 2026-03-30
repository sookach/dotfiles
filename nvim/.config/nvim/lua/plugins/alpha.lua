return {
  spec = 'https://github.com/goolord/alpha-nvim',
  config = function()
    local alpha = require('alpha')
    alpha.setup(require('alpha.themes.dashboard').config)
  end
}
