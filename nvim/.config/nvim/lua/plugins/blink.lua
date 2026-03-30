return {
  spec = { src = 'https://github.com/saghen/blink.cmp', version = 'v1.10.1' },
  config = function()
    local ok, blink = pcall(require, 'blink.cmp')
    if ok then
      blink.setup({
        signature = { enabled = true },
        keymap = { preset = 'default' },
        appearance = { nerd_font_variant = 'mono' },
        completion = { documentation = { auto_show = false } },
        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
        fuzzy = {
          implementation = "prefer_rust_with_warning",
          prebuilt_binaries = { download = true, force_version = "v1.10.1" }
        }
      })
    end
  end
}