return {
  spec = 'https://github.com/ibhagwan/fzf-lua',
  config = function()
    local ok, fzf = pcall(require, 'fzf-lua')
    if ok then
      fzf.setup({ files = { cmd = "fd --type f" } })
      vim.keymap.set('n', '<leader>ff', fzf.builtin, { desc = "Fzf Builtin" })
      vim.keymap.set('n', '<leader>fs', fzf.files, { desc = "Fzf Files" })
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Fzf Grep" })
    end
  end
}