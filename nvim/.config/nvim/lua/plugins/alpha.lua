return {
  spec = 'https://github.com/goolord/alpha-nvim',
  config = function()
    local ok, alpha = pcall(require, 'alpha')
    if ok then
      alpha.setup(require('alpha.themes.dashboard').config)
    end
  end
}