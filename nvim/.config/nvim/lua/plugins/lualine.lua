return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = (function()
    local colors = {
      bg       = "#202328",
      fg       = "#bbc2cf",
      yellow   = "#ECBE7B",
      cyan     = "#008080",
      darkblue = "#081633",
      green    = "#98be65",
      orange   = "#FF8800",
      violet   = "#a9a1e1",
      magenta  = "#c678dd",
      blue     = "#51afef",
      red      = "#ec5f67",
    }

    local conditions = {
      buffer_not_empty = function()
        return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
      end,
      hide_in_width = function()
        return vim.fn.winwidth(0) > 80
      end,
    }

    return {
      options = {
        component_separators = "",
        section_separators = "",
        theme = {
          normal = { c = { fg = colors.fg, bg = colors.bg } },
          inactive = { c = { fg = colors.fg, bg = colors.bg } },
        },
      },

      sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_y = {},
        lualine_z = {},

        lualine_c = {
          {
            function() return "▊" end,
            color = { fg = colors.blue },
            padding = { left = 0, right = 1 },
          },
          {
            function() return "" end,
            color = function()
              local mode_color = {
                n = colors.red,
                i = colors.green,
                v = colors.blue,
                V = colors.blue,
                c = colors.magenta,
                R = colors.violet,
                t = colors.red,
              }
              return { fg = mode_color[vim.fn.mode()] }
            end,
            padding = { right = 1 },
          },
          { "filesize", cond = conditions.buffer_not_empty },
          {
            "filename",
            cond = conditions.buffer_not_empty,
            color = { fg = colors.magenta, gui = "bold" },
          },
          { "location" },
          { "progress", color = { fg = colors.fg, gui = "bold" } },
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = { error = " ", warn = " ", info = " " },
          },
          { function() return "%=" end },
          {
            function()
              local buf_ft = vim.bo.filetype
              for _, client in ipairs(vim.lsp.get_clients()) do
                if client.config.filetypes
                    and vim.tbl_contains(client.config.filetypes, buf_ft)
                then
                  return client.name
                end
              end
              return "No Active LSP"
            end,
            icon = " LSP:",
            color = { fg = "#ffffff", gui = "bold" },
          },
        },

        lualine_x = {
          {
            "o:encoding",
            fmt = string.upper,
            cond = conditions.hide_in_width,
            color = { fg = colors.green, gui = "bold" },
          },
          {
            "fileformat",
            fmt = string.upper,
            icons_enabled = false,
            color = { fg = colors.green, gui = "bold" },
          },
          {
            "branch",
            icon = "",
            color = { fg = colors.violet, gui = "bold" },
          },
          {
            "diff",
            symbols = { added = " ", modified = "󰝤 ", removed = " " },
            cond = conditions.hide_in_width,
          },
          {
            function() return "▊" end,
            color = { fg = colors.blue },
            padding = { left = 1 },
          },
        },
      },

      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
    }
  end)(),
}
