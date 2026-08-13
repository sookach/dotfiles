vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.mouse = 'a'
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.mousescroll = "ver:1,hor:1"

-- UI & Search Optimizations
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

vim.keymap.set('n', 'tl', ':tabnext<cr>')
vim.keymap.set('n', 'th', ':tabprevious<cr>')
vim.keymap.set('n', 'tj', ':tabnew<cr>')
vim.keymap.set('n', 'tk', ':tabclose<cr>')


vim.pack.add {
  'https://github.com/scottmckendry/cyberdream.nvim.git',
  'https://github.com/ntbbloodbath/doom-one.nvim'
}
require('cyberdream').setup {
  transparent = true,
  cache = true,
  styles = {
    sidebars = "transparent",
    floats = "transparent",
  },
}

vim.g.doom_one_transparent_background = true

vim.cmd.colorscheme("cyberdream")

vim.pack.add {
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/nvim-lualine/lualine.nvim'
}
require('lualine').setup { options = { theme = "auto" } }

vim.pack.add {
  'https://github.com/MunifTanjim/nui.nvim.git',
  'https://github.com/rcarriga/nvim-notify.git',
  'https://github.com/folke/noice.nvim.git'
}
require("notify").setup { background_colour = "#000000" }
require("noice").setup {
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
    },
  },
  presets = {
    bottom_search = false,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
}
vim.keymap.set('n', '<leader>ud', ':NoiceDismiss<cr>')

vim.pack.add { "https://github.com/sphamba/smear-cursor.nvim" }
require('smear_cursor').setup {}

vim.pack.add { 'https://github.com/nvim-lua/plenary.nvim.git' }
vim.pack.add { 'https://github.com/mikavilpas/yazi.nvim.git' }
vim.keymap.set({ 'n', 'v' }, '<leader>y', ':Yazi<cr>')

vim.pack.add { 'https://github.com/ibhagwan/fzf-lua.git' }
local fzf = require('fzf-lua')
--[[
fzf.setup {
  grep = {
    -- --hidden includes dotfiles (.config, .env, etc.)
    -- --no-ignore bypasses .gitignore
    rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4000 --hidden --no-ignore",
    -- Search hidden files, but keep respecting .gitignore
    --  rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4000 --hidden"
  }
}
--]]

vim.keymap.set('n', '<leader>ff', fzf.files, { desc = "Find Files" })
vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = "Live Grep" })

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

vim.pack.add { 'https://github.com/nvim-treesitter/nvim-treesitter' }
require('nvim-treesitter').install {
  'awk',
  'bash',
  'c',
  'cmake',
  'cpp',
  'css',
  'git_config',
  'git_rebase',
  'gitattributes',
  'gitcommit',
  'gitignore',
  'json',
  'llvm',
  'lua',
  'make',
  'mlir',
  'python',
  'toml',
  'vim',
  'vimdoc',
  'yaml',
  'zsh',
}
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    -- Start Treesitter
    pcall(vim.treesitter.start)

    -- Enable Folding (only set if parser is available)
    if pcall(vim.treesitter.get_parser) then
      vim.wo[0][0].foldmethod = 'expr'
      vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      -- Keep folds open by default when opening a file (optional but recommended)
      vim.wo.foldlevel = 99
    end

    -- Enable Experimental Tree-sitter Indentation
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

vim.pack.add {
  'https://github.com/saghen/blink.lib',
  'https://github.com/saghen/blink.cmp',
}
local blink = require('blink.cmp')
blink.setup {
  keymap = { preset = 'default' },
  appearance = { use_nvim_cmp_as_default = true },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
}
blink.build():pwait()

vim.keymap.set({ 'n', 'v' }, 'gf', vim.lsp.buf.format)
vim.keymap.set({ 'n', 'v' }, 'grd', vim.lsp.buf.definition)

vim.lsp.enable('clangd')
vim.lsp.enable('cmake')
vim.lsp.enable('cssls')
vim.lsp.enable('jsonls')
vim.lsp.enable('lua_ls')
vim.lsp.enable('marksman')
vim.lsp.enable('taplo')

vim.api.nvim_create_user_command("PackClean", function()
  local inactive = {}
  for _, p in ipairs(vim.pack.get()) do
    if not p.active then
      table.insert(inactive, p.spec.name)
    end
  end

  if #inactive > 0 then
    vim.pack.del(inactive)
    print("Cleaned up " .. #inactive .. " inactive plugin(s).")
  else
    print("Your native plugins are already clean!")
  end
end, {})
