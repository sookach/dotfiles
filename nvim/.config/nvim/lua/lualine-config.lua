local rounded_edge = {
  left = "",
  right = "",
}
local colors = require("cyberdream.colors").default
local mode_color = function()
  local mode_colors = {
    n = colors.blue,
    i = colors.green,
    v = colors.magenta,
    V = colors.magenta,
    c = colors.red,
  }

  return {
    fg = mode_colors[vim.fn.mode()] or colors.blue,
    bg = '#000000',
    gui = 'bold',
  }
end

vim.api.nvim_set_hl(0, "LualineTabActive", {
  fg = "#ffffff",
  bg = "#000000",
})

vim.api.nvim_set_hl(0, "LualineTabInactive", {
  fg = colors.grey,
  bg = "#000000",
})

return {
  options = {
    icons_enabled = true,
    globalstatus = true,
    section_separators = {
      left = "",
      right = "",
    },

    component_separators = {
      left = "",
      right = "",
    },
    refresh = {
      statusline = 100,
      tabline = 100,
      winbar = 100,
    },
  },
  sections = {
    lualine_a = {
      {
        function()
          return ''
          --  return ''
        end,
        separator = {
          left = '     ' .. rounded_edge.left,
          right = nil,
        },
        color = mode_color,
      },
      {
        "mode",
        separator = {
          left = rounded_edge.left,
          right = nil,
        },
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        "tabs",
        mode = 0, -- shows buffer numbers
        tabs_color = {
          active = "LualineTabActive",
          inactive = "LualineTabInactive",
        },
        symbols = {
          modified = "",
          alternate_file = "",
          directory = "",
        },
        icons_enabled = false,
      },
      {
        function()
          return ''
        end,
        color = {
          fg = colors.orange,
          bg = '#000000',
          gui = 'bold',
        },
        padding = {
          left = 1,
          right = 0,
        }
      },
      {
        "branch",
        icon = '',
        separator = nil,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        function()
          return ''
        end,
        color = {
          fg = colors.pink,
          bg = '#000000',
          gui = 'bold',
        },
        separator = nil,
      },
      {
        "filename",
        separator = nil,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        'fileformat',
        separator = nil,
        color = {
          fg = colors.yellow,
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        'encoding',
        separator = nil,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        'filetype',
        separator = nil,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        function()
          return ''
        end,
        seperator = nil,
        color = {
          fg = colors.green,
          bg = '#000000',
          gui = 'bold',
        },
      },
      {
        "location",
        separator = {
          left = nil,
          right = rounded_edge.right,
        },
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
}
