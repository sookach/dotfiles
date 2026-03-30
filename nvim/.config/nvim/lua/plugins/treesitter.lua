return {
  spec = { src = 'https://github.com/nvim-treesitter/nvim-treesitter', branch = 'master' },
  config = function()
    -- Fallback for nvim-treesitter v1.0.0+ (main branch)
    require('nvim-treesitter').setup {}

    -- Enable highlight for all supported buffers
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
        if lang then
          pcall(vim.treesitter.start)
        end
      end
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "PackChanged",
      callback = function()
        vim.cmd("TSUpdate")
      end,
    })
  end
}
