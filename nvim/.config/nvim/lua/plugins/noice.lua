return {
  spec = 'https://github.com/folke/noice.nvim',
  config = function()
    local ok, noice = pcall(require, 'noice')
    if ok then
      noice.setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.extract_stack_trace"] = true,
            ["navigation.lsp_signature_help_enabled"] = true,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
        },
      })
    end
  end
}