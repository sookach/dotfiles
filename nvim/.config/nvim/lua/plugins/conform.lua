return {
  spec = 'https://github.com/stevearc/conform.nvim',
  config = function()
    local ok, conform = pcall(require, 'conform')
    if ok then
      conform.setup({
        formatters_by_ft = {
          python = { "black" },
          sh = { "shfmt" },
          objc = { "clang-format" },
          objcpp = { "clang-format" },
        },
      })
    end
  end
}