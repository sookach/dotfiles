return {
  spec = 'https://github.com/stevearc/conform.nvim',
  config = function()
    local conform = require('conform')
    conform.setup {
      formatters_by_ft = {
        python = { "black" },
        sh = { "shfmt" },
        objc = { "clang-format" },
        objcpp = { "clang-format" },
      },
    }
  end
}
