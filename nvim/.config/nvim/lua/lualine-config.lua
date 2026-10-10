local fg_color = '#ffffff'
local bg_color = '#000000'

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
    bg = bg_color,
    gui = 'bold',
  }
end


vim.api.nvim_set_hl(0, "LualineTabActive", {
  fg = fg_color,
  bg = bg_color,
})

vim.api.nvim_set_hl(0, "LualineTabInactive", {
  fg = colors.grey,
  bg = fg_color,
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
          left = ' ' .. rounded_edge.left,
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
          fg = fg_color,
          bg = bg_color,
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
          bg = bg_color,
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
          fg = fg_color,
          bg = bg_color,
          gui = 'bold',
        },
      },
      {
        function()
          return ''
        end,
        color = {
          fg = colors.pink,
          bg = bg_color,
          gui = 'bold',
        },
        separator = nil,
      },
      {
        "filename",
        separator = nil,
        color = {
          fg = fg_color,
          bg = bg_color,
          gui = 'bold',
        },
      },
      {
        'fileformat',
        separator = nil,
        color = {
          fg = colors.yellow,
          bg = bg_color,
          gui = 'bold',
        },
      },
      {
        'encoding',
        separator = nil,
        color = {
          fg = fg_color,
          bg = bg_color,
          gui = 'bold',
        },
      },
      {
        'filetype',
        separator = nil,
        color = {
          fg = fg_color,
          bg = bg_color,
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
          bg = bg_color,
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
          fg = fg_color,
          bg = bg_color,
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
