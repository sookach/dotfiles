return {
  "folke/noice.nvim",
  dependencies = {
    -- Which-key needs these for the UI
    "MunifTanjim/nui.nvim",
    -- Optional but highly recommended for notifications
    "rcarriga/nvim-notify",
  },
  opts = {
    lsp = {
      -- override markdown rendering so that cmp and other plugins use Treesitter
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.extract_stack_trace"] = true,
        ["navigation.lsp_signature_help_enabled"] = true,
      },
    },
    -- Use the "clean" preset for a less intrusive feel
    presets = {
      bottom_search = true, -- classic bottom search bar
      command_palette = true, -- center-screen command line
      long_message_to_split = true, -- split for long messages
    },
  },
}
