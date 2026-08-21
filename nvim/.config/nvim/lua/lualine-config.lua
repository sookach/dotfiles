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

return {
  options = {
    icons_enabled = true,
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
        padding = 0,
        color = mode_color,
      },
      {
        "mode",
        separator = {
          left = rounded_edge.left,
          right = nil,
        },
        padding = 1,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
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
        padding = 0,
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
        padding = {
          left = 0,
          right = 1,
        }
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
        padding = 1,
        separator = nil,
      },
      {
        "filename",
        separator = {
          left = nil,
          right = rounded_edge.right,
        },
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
        padding = 0
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {
      {
        'fileformat',
        separator = {
          left = rounded_edge.left,
          right = nil
        },
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
        sepeartor = nil,
        padding = {
          left = 1,
          right = 0,
        },
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
        padding = 0,
        color = {
          fg = '#ffffff',
          bg = '#000000',
          gui = 'bold',
        },
      }
    },
  },
}
