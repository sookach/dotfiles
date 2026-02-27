return {
  'stevearc/conform.nvim',
  opts = {
    formatters_by_ft = {
      python = { "black" },
      sh = { "shfmt" },
      objc = { "clang-format" },
      objcpp = { "clang-format" },
    },
  },
}
