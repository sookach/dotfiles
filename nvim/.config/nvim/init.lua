vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.mouse = 'a'
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.mousescroll = "ver:1,hor:1"

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set({ 'n' }, 'tl', ':tabnext<cr>')
vim.keymap.set({ 'n' }, 'th', ':tabprevious<cr>')
vim.keymap.set({ 'n' }, 'tj', ':tabnew<cr>')
vim.keymap.set({ 'n' }, 'tk', ':tabclose<cr>')

vim.keymap.set({ 'n', 'v' }, 'gf', vim.lsp.buf.format)
vim.keymap.set({ 'n', 'v' }, 'grd', vim.lsp.buf.definition)


vim.lsp.enable('clangd')
vim.lsp.enable('cmake')
vim.lsp.enable('lua_ls')

vim.pack.add { 'https://github.com/ibhagwan/fzf-lua.git' }
vim.pack.add { 'https://github.com/nvim-treesitter/nvim-treesitter' }
vim.pack.add {
  'https://github.com/saghen/blink.lib',
  'https://github.com/saghen/blink.cmp'
}

local cmp = require('blink.cmp')
cmp.build():pwait()
cmp.setup()

vim.pack.add { 'https://github.com/mikavilpas/yazi.nvim.git' }
vim.pack.add { 'https://github.com/nvim-lua/plenary.nvim.git' }

vim.keymap.set({ 'n', 'v' }, '<leader>y', ':Yazi<cr>')

vim.pack.add {
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/nvim-lualine/lualine.nvim'
}
require('lualine').setup {
  options = {
    theme = "auto", -- "auto" will set the theme dynamically based on the colorscheme
  },
}

vim.pack.add {
  'https://github.com/folke/noice.nvim.git',
  'https://github.com/MunifTanjim/nui.nvim.git',
  'https://github.com/rcarriga/nvim-notify.git'
}
require("notify").setup({
  background_colour = "#000000",
})

require("noice").setup({
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
    },
  },
  presets = {
    bottom_search = false,        -- use a classic bottom cmdline for search
    command_palette = true,       -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false,           -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = false,       -- add a border to hover docs and signature help
  },
})

-- 1. Load cyberdream using Neovim's native pack add
vim.pack.add { 'https://github.com/scottmckendry/cyberdream.nvim.git' }

-- 2. Configure Cyberdream options
require("cyberdream").setup({
  -- Enable transparent background to let Ghostty's glass show through
  transparent = true,

  -- High contrast Vivaldi/Cyberpunk vibes
  cache = true, -- Improves startup speed
  styles = {
    sidebars = "transparent",
    floats = "transparent",
  },
})

-- 3. Set the colorscheme
vim.cmd("colorscheme cyberdream")

vim.api.nvim_create_user_command("PackClean", function()
  local inactive = {}

  -- Gather all plugins tracked by the engine
  for _, p in ipairs(vim.pack.get()) do
    -- If it's on disk but not currently called by vim.pack.add()
    if not p.active then
      table.insert(inactive, p.spec.name)
    end
  end

  -- Delete them if any are found
  if #inactive > 0 then
    vim.pack.del(inactive)
    print("Cleaned up " .. #inactive .. " inactive plugin(s).")
  else
    print("Your native plugins are already clean!")
  end
end, {})

vim.pack.add { "https://github.com/sphamba/smear-cursor.nvim" }
require('smear_cursor').setup {}

-- vim.pack.add { 'https://github.com/rktjmp/lush.nvim' }
-- vim.pack.add { 'https://github.com/uloco/bluloco.nvim' }
-- require('bluloco').setup { transparent = true }
-- vim.cmd.colorscheme('bluloco')
