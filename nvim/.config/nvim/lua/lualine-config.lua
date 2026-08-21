local old_bg = '#16181a'
local space = {
  function()
    return ' '
  end,
}
local rounded_edge = {
  left = "",
  right = "",
}
local colors = require("cyberdream.colors").default

return {
  options = {
    icons_enabled = true,
  },
  sections = {
    lualine_a = {
      {
        "mode",
        separator = {
          left = ' ' .. rounded_edge.left,
          right = rounded_edge.right
        },
        color = function()
          local mode_colors = {
            n = colors.blue,
            i = colors.green,
            v = colors.magenta,
            V = colors.magenta,
            c = colors.red,
          }

          return {
            fg = old_bg,
            bg = mode_colors[vim.fn.mode()] or colors.blue,
            gui = 'bold',
          }
        end,
      },
      space,
      {
        "branch",
        icon = '',
        separator = rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.cyan,
          gui = 'bold',
        },
      },
      space,
      {
        "filename",
        separator = rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.pink,
          gui = 'bold',
        },
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {
      {
        'encoding',
        separator = rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.fg,
          gui = 'bold',
        },
      },
      {
        'fileformat',
        rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.fg,
          gui = 'bold',
        },
      },
      {
        'filetype',
        separator = rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.fg,
          gui = 'bold',
        },
      },
      --[[
      space,
      {
        'progress',
        separator = rounded_edge,
        color = {
          fg = old_bg,
          bg = colors.green,
          gui = 'bold',
        },
      },
      --]]
      space,
      {
        "location",
        separator = {
          left = rounded_edge.left,
          right = rounded_edge.right .. ' ',
        },
        color = {
          fg = old_bg,
          bg = colors.green,
          gui = 'bold',
        },
      }
    },
  },
}
