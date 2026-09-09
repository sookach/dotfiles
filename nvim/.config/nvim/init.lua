vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.clipboard = 'unnamedplus'
vim.opt.termguicolors = true
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.mouse = 'a'
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.mousescroll = 'ver:1,hor:1'
vim.opt.showtabline = 0

-- UI & Search Optimizations
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.signcolumn = 'yes'
vim.opt.scrolloff = 8

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

vim.keymap.set('n', 'tl', ':tabnext<cr>')
vim.keymap.set('n', 'th', ':tabprevious<cr>')
vim.keymap.set('n', 'tj', ':tabnew<cr>')
vim.keymap.set('n', 'tk', ':tabclose<cr>')

vim.keymap.set("n", "<leader>co", function()
  vim.cmd.edit(vim.env.MYVIMRC)
end, { desc = "Edit Neovim config" })

vim.keymap.set("n", "<leader>cs", function()
  vim.cmd.source(vim.env.MYVIMRC)
end, { desc = "Reload Neovim config" })

vim.keymap.set("n", "<leader>cv", function()
  vim.cmd.vsplit(vim.env.MYVIMRC)
end, { desc = "Open Neovim config in vertical split" })

vim.keymap.set("n", "<leader>ch", function()
  vim.cmd.split(vim.env.MYVIMRC)
end, { desc = "Open Neovim config in horizontal split" })

vim.pack.add {
  'https://github.com/scottmckendry/cyberdream.nvim.git',
  'https://github.com/ntbbloodbath/doom-one.nvim'
}
require('cyberdream').setup {
  transparent = true,
  cache = false,
  styles = {
    sidebars = 'transparent',
    floats = 'transparent',
  },
}

vim.g.doom_one_transparent_background = true

vim.cmd.colorscheme('cyberdream')

vim.pack.add {
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/nvim-lualine/lualine.nvim'
}

require('lualine').setup(require('lualine-config'))

vim.pack.add {
  'https://github.com/MunifTanjim/nui.nvim.git',
  'https://github.com/rcarriga/nvim-notify.git',
  'https://github.com/folke/noice.nvim.git'
}
require('notify').setup { background_colour = '#000000' }
require('noice').setup {
  lsp = {
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,
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

-- vim.pack.add { 'https://github.com/sphamba/smear-cursor.nvim' }
-- require('smear_cursor').setup {}

vim.pack.add { 'https://github.com/nvim-lua/plenary.nvim.git' }
vim.pack.add { 'https://github.com/mikavilpas/yazi.nvim.git' }
vim.keymap.set({ 'n', 'v' }, '<leader>y', ':Yazi<cr>')

vim.pack.add { 'https://github.com/ibhagwan/fzf-lua.git' }
local fzf = require('fzf-lua')

vim.keymap.set('n', '<leader>ff', fzf.files, { desc = "Find Files" })
vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = "Live Grep" })

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

vim.pack.add { 'https://github.com/lewis6991/gitsigns.nvim' }

vim.pack.add { 'https://github.com/folke/flash.nvim' }
local flash = require('flash')
flash.setup {}

vim.keymap.set({ "n", "x", "o" }, "<leader>s", function()
  flash.jump()
end, { desc = "Flash" })

vim.keymap.set({ "n", "x", "o" }, "<leader>S", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })

vim.keymap.set("o", "<leader>r", function()
  require("flash").remote()
end, { desc = "Remote Flash" })

vim.pack.add { 'https://github.com/nvim-treesitter/nvim-treesitter' }
require('nvim-treesitter').install {
  'awk',
  'bash',
  'c',
  'capnp',
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
  'perl',
  'python',
  'swift',
  'toml',
  'vim',
  'vimdoc',
  'yaml',
  'zsh',
}
vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    -- Start Treesitter
    pcall(vim.treesitter.start)

    -- Enable Folding (only set if parser is available)
    if pcall(vim.treesitter.get_parser) then
      vim.wo[0][0].foldmethod = 'expr'
      vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
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
blink.build():pwait()
blink.setup {
  keymap = { preset = 'default' },
  appearance = { use_nvim_cmp_as_default = true },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
}

local function format_buffer()
  if vim.bo.filetype == 'python' then
    if vim.fn.executable('black') == 0 then
      vim.notify('black is not installed', vim.log.levels.ERROR)
      return
    end

    local filename = vim.api.nvim_buf_get_name(0)
    local input = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    local result = vim.system({ 'black', '--quiet', '--stdin-filename', filename, '-' }, {
      stdin = input,
      text = true,
    }):wait()

    if result.code ~= 0 then
      vim.notify(result.stderr or 'black failed', vim.log.levels.ERROR)
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result.stdout, '\n', { plain = true }))
    vim.api.nvim_win_set_cursor(0, cursor)
    return
  end

  vim.lsp.buf.format()
end

vim.keymap.set({ 'n', 'v' }, 'gf', format_buffer)
vim.keymap.set({ 'n', 'v' }, 'grd', vim.lsp.buf.definition)

vim.filetype.add {
  extension = {
    capnp = 'capnp',
  },
}

vim.lsp.enable('capnprotols')
vim.lsp.enable('clangd')
vim.lsp.enable('cmake')
vim.lsp.enable('cssls')
vim.lsp.enable('jsonls')
vim.lsp.enable('lua_ls')
vim.lsp.enable('marksman')
vim.lsp.enable('perlnavigator')
vim.lsp.enable('sourcekit')
vim.lsp.enable('taplo')
vim.lsp.enable("zuban")

vim.pack.add { 'https://github.com/nvimdev/lspsaga.nvim' }
local lspsaga = require('lspsaga')
lspsaga.setup {
  symbol_in_winbar = { enable = false },
  outline = { layout = 'normal' }
}

vim.keymap.set({ 'n' }, '<leader>lk', '<cmd>Lspsaga hover_doc<cr>')
vim.keymap.set({ 'n' }, '<leader>ldp', '<cmd>Lspsaga peek_definition<cr>')
vim.keymap.set({ 'n' }, '<leader>ldj', '<cmd>Lspsaga goto_definition<cr>')
vim.keymap.set({ 'n' }, '<leader>lo', '<cmd>Lspsaga outline<cr>')
vim.keymap.set({ 'n' }, '<leader>lij', '<cmd>Lspsaga diagnostic_jump_next<cr>')
vim.keymap.set({ 'n' }, '<leader>lik', '<cmd>Lspsaga diagnostic_jump_next<cr>')

vim.api.nvim_create_user_command('PackClean', function()
  local inactive = {}
  for _, p in ipairs(vim.pack.get()) do
    if not p.active then
      table.insert(inactive, p.spec.name)
    end
  end

  if #inactive > 0 then
    vim.pack.del(inactive)
    print('Cleaned up ' .. #inactive .. ' inactive plugin(s).')
  else
    print('Your native plugins are already clean!')
  end
end, {})
