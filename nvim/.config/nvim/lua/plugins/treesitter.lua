return {
  spec = { src = 'https://github.com/nvim-treesitter/nvim-treesitter', branch = 'master' },
  config = function()
    local ok, configs = pcall(require, 'nvim-treesitter.configs')
    if ok then
      configs.setup({
        highlight = { enable = true },
        ensure_installed = { "lua", "vim", "vimdoc", "query" },
      })
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "PackChanged",
      callback = function()
        pcall(function() vim.cmd("TSUpdate") end)
      end,
    })
  end
}