-- Crack: pure black neutral monochrome (standalone, zero plugin dependencies)
vim.cmd("highlight clear")
if vim.fn.exists('syntax_on') == 1 then
  vim.cmd('syntax reset')
end
vim.o.background = 'dark'
vim.g.colors_name = 'crack'

local cfg = vim.tbl_extend('force', {
  transparent = false,
  transparent_floats = true,
  no_italic = false,
  accessibility_contrast = 0, -- 0..10 WCAG contrast boost toward 7.0:1 AAA
  cursor_sync = false,        -- sync terminal cursor color per mode via OSC 12
}, type(vim.g.crack) == 'table' and vim.g.crack or {})

if vim.g.crack_transparent ~= nil then
  cfg.transparent = vim.g.crack_transparent
end

local base_palette = {
  bg        = '#000000', -- pure black (opaque anchor / inverted badge fg)
  float_bg  = '#080808', -- floating windows & completion menu
  cursor    = '#101010', -- cursor line & virtual-text pill
  visual    = '#1A1A1A', -- selection & inline code
  border    = '#2A2A2A', -- window borders & backdrops
  subtle    = '#383838', -- line numbers, whitespace, indent guides
  dim       = '#585858', -- comments, hints, secondary chrome
  muted     = '#808080', -- punctuators, operators, delimiters
  secondary = '#B8B8B8', -- UI warnings & secondary headings (never code identifiers)  [value unreadable in OCR: guessed]
  fg        = '#E0E0E0', -- all code identifiers, types, literals & functions
  bright    = '#FFFFFF', -- control-flow keywords, errors, active emphasis
}

-- Self-contained WCAG 2.1 contrast scaler (replaces mfd.compute_accessible_colors)
local function hex_to_rgb(hex)
  hex = hex:gsub('#', '')
  return tonumber(hex:sub(1, 2), 16) / 255,
      tonumber(hex:sub(3, 4), 16) / 255,
      tonumber(hex:sub(5, 6), 16) / 255
end

local function rgb_to_hex(r, g, b)
  local function clamp(x)
    return math.max(0, math.min(255, math.floor(x * 255 + 0.5)))
  end
  return string.format('#%02X%02X%02X', clamp(r), clamp(g), clamp(b))
end

local function srgb_linear(ch)
  return ch <= 0.04045 and (ch / 12.92) or (((ch + 0.055) / 1.055) ^ 2.4)
end

local function luminance(hex)
  local r, g, b = hex_to_rgb(hex)
  return 0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b)
end

local function contrast_ratio(hex1, hex2)
  local l1, l2 = luminance(hex1), luminance(hex2)
  if l1 < l2 then l1, l2 = l2, l1 end
  return (l1 + 0.05) / (l2 + 0.05)
end

local function scale_to_contrast(src_hex, bg_surfaces, target, t)
  local ok_all = true
  for _, bg in ipairs(bg_surfaces) do
    if contrast_ratio(src_hex, bg) < target then
      ok_all = false
      break
    end
  end
  if ok_all then return src_hex end

  local r, g, b = hex_to_rgb(src_hex)
  local lo, hi_f = 0.0, 1.0
  for _ = 1, 40 do
    local mid = (lo + hi_f) / 2
    local candidate = rgb_to_hex(r + (1 - r) * mid, g + (1 - g) * mid, b + (1 - b) * mid)
    local ok = true
    for _, bg in ipairs(bg_surfaces) do
      if contrast_ratio(candidate, bg) < target then
        ok = false
        break
      end
    end
    if ok then hi_f = mid else lo = mid end
  end
  local k = hi_f * t
  return rgb_to_hex(r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k)
end

local function compute_palette(palette, level)
  level = math.max(0, math.min(10, tonumber(level) or 0))
  if level == 0 then return vim.deepcopy(palette) end
  local out = vim.deepcopy(palette)
  local surfaces = { palette.bg, palette.float_bg, palette.cursor }
  local t = level / 10.0
  for _, key in ipairs({ 'border', 'subtle', 'dim', 'muted', 'secondary', 'fg', 'bright' }) do
    out[key] = scale_to_contrast(palette[key], surfaces, 7.1, t)
  end
  return out
end

local c = compute_palette(base_palette, cfg.accessibility_contrast)

local surface_bg = cfg.transparent and 'NONE' or c.bg
local float_bg = (cfg.transparent and cfg.transparent_floats) and 'NONE' or c.float_bg
local comment = c.dim

local function hi(group, opts)
  if cfg.no_italic and opts.italic then
    opts = vim.tbl_extend('force', opts, { italic = false })
    opts.italic = nil
  end
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor
hi('Normal', { fg = c.fg, bg = surface_bg })
hi('NormalNC', { fg = c.fg, bg = surface_bg })
hi('NormalFloat', { fg = c.fg, bg = float_bg })
hi('FloatBorder', { fg = c.border, bg = float_bg })
hi('FloatTitle', { fg = c.fg, bg = float_bg, bold = true })
hi('FloatFooter', { fg = c.dim, bg = float_bg })
hi('FloatShadow', { bg = c.border, blend = 80 })
hi('FloatShadowThrough', { bg = c.border, blend = 100 })
hi('Cursor', { fg = c.bg, bg = c.bright })
hi('lCursor', { fg = c.bg, bg = c.bright })
hi('CursorIM', { fg = c.bg, bg = c.bright })
hi('TermCursor', { fg = c.bg, bg = c.bright })
hi('TermCursorNC', { fg = c.bg, bg = c.dim })
hi('CursorNormal', { fg = c.bg, bg = '#D0D0D0' })      -- neutral off-white, home base
hi('CursorInsert', { fg = c.bg, bg = c.bright })       -- pure white, hot
hi('CursorVisual', { fg = c.bg, bg = c.muted })        -- mid-gray, selection
hi('CursorReplace', { fg = c.bg, bg = c.fg })          -- bright neutral
hi('CursorCommand', { fg = c.bg, bg = '#D0D0D0' })     -- same as normal
hi('CursorLine', { bg = c.cursor })
hi('CursorColumn', { bg = c.cursor })
hi('ColorColumn', { bg = c.cursor })
hi('LineNr', { fg = c.subtle })
hi('LineNrAbove', { fg = c.subtle })
hi('LineNrBelow', { fg = c.subtle })
hi('CursorLineNr', { fg = c.fg, bold = true })
hi('SignColumn', { bg = 'NONE' })
hi('VertSplit', { fg = c.border, bg = 'NONE' })
hi('WinSeparator', { fg = c.border, bg = 'NONE' })
hi('StatusLine', { fg = c.fg, bg = c.cursor })
hi('StatusLineNC', { fg = c.dim, bg = c.cursor })
hi('TabLine', { fg = c.dim, bg = c.cursor })
hi('TabLineFill', { bg = surface_bg })
hi('TabLineSel', { fg = c.fg, bg = surface_bg, bold = true })
hi('WinBar', { fg = c.fg, bg = surface_bg, bold = true })
hi('WinBarNC', { fg = c.dim, bg = surface_bg })
hi('MsgArea', { fg = c.fg, bg = surface_bg })
hi('MsgSeparator', { fg = c.border, bg = surface_bg })

-- Popup / Completion menu (kept opaque so borderless menus stay legible)
hi('Pmenu', { fg = c.fg, bg = c.float_bg })
hi('PmenuSel', { fg = c.bg, bg = c.fg, bold = true })
hi('PmenuKind', { fg = c.dim, bg = c.float_bg })
hi('PmenuKindSel', { fg = c.bg, bg = c.fg, bold = true })
hi('PmenuSbar', { bg = c.float_bg })
hi('PmenuThumb', { bg = c.dim })
hi('PmenuMatch', { fg = c.bright, bold = true })
hi('PmenuMatchSel', { fg = c.bg, bg = c.fg, bold = true })
hi('PmenuExtra', { fg = c.dim, bg = c.float_bg })
hi('PmenuExtraSel', { fg = c.bg, bg = c.fg })

-- Selection, Search & Matching
hi('Visual', { bg = c.visual })
hi('VisualNOS', { bg = c.visual })
hi('Search', { fg = c.bg, bg = c.secondary, bold = true })
hi('IncSearch', { fg = c.bg, bg = c.bright, bold = true })
hi('CurSearch', { fg = c.bg, bg = c.bright, bold = true })
hi('Substitute', { fg = c.bg, bg = c.fg, bold = true })
hi('MatchParen', { fg = c.bright, bg = c.visual, bold = true })

-- Folds, Whitespace & Messages
hi('Folded', { fg = c.dim, bg = c.cursor, italic = true })
hi('FoldColumn', { fg = c.dim, bg = 'NONE' })
hi('NonText', { fg = c.subtle })
hi('SpecialKey', { fg = c.subtle })
hi('Whitespace', { fg = c.subtle })
hi('EndOfBuffer', { fg = c.subtle, bg = surface_bg })
hi('Directory', { fg = c.fg, bold = true })
hi('Title', { fg = c.fg, bold = true })
hi('ErrorMsg', { fg = c.bright, bg = surface_bg, bold = true })
hi('WarningMsg', { fg = c.secondary, bold = true })
hi('MoreMsg', { fg = c.fg, bold = true })
hi('ModeMsg', { fg = c.fg, bold = true })
hi('Question', { fg = c.fg, bold = true })
hi('WildMenu', { fg = c.bg, bg = c.fg, bold = true })
hi('QuickFixLine', { bg = c.visual, bold = true })
hi('qfLineNr', { fg = c.dim })
hi('qfFileName', { fg = c.secondary })
hi('Conceal', { fg = c.dim })

-- Spelling (dotted underline preserves clean geometry without hiding typos)
hi('SpellBad', { underdotted = true, sp = c.bright })
hi('SpellCap', { underdotted = true, sp = c.muted })
hi('SpellLocal', { underdotted = true, sp = c.dim })
hi('SpellRare', { underdotted = true, sp = c.dim })

-- Diffs (luminance + strikethrough separates +/- without color)
hi('DiffAdd', { fg = c.bright, bg = '#141414' })
hi('DiffChange', { bg = '#0A0A0A' })
hi('DiffDelete', { fg = c.dim, bg = '#0A0A0A', strikethrough = true })
hi('DiffText', { fg = c.bright, bg = '#242424', bold = true })
hi('Added', { fg = c.fg })
hi('Changed', { fg = c.muted })
hi('Removed', { fg = c.dim, strikethrough = true })

-- Legacy Vim Syntax: monotone identifiers with dimmed punctuators
hi('Comment', { fg = comment, italic = true })
hi('Constant', { fg = c.fg })
hi('String', { fg = c.fg, italic = true })
hi('Character', { fg = c.fg })
hi('Number', { fg = c.fg })
hi('Boolean', { fg = c.fg, bold = true })
hi('Float', { fg = c.fg })
hi('Identifier', { fg = c.fg })
hi('Function', { fg = c.fg, bold = true })
hi('Statement', { fg = c.bright, bold = true })
hi('Conditional', { fg = c.bright, bold = true })
hi('Repeat', { fg = c.bright, bold = true })
hi('Label', { fg = c.fg, bold = true })
hi('Operator', { fg = c.muted })
hi('Keyword', { fg = c.bright, bold = true })
hi('Exception', { fg = c.bright, bold = true })
hi('PreProc', { fg = c.fg, bold = true })
hi('Include', { fg = c.fg, bold = true })
hi('Define', { fg = c.fg, bold = true })
hi('Macro', { fg = c.fg, bold = true })
hi('PreCondit', { fg = c.fg, bold = true })
hi('Type', { fg = c.fg, bold = true })
hi('StorageClass', { fg = c.fg, bold = true })
hi('Structure', { fg = c.fg, bold = true })
hi('Typedef', { fg = c.fg, bold = true })
hi('Special', { fg = c.fg })
hi('SpecialChar', { fg = c.bright, bold = true })
hi('Tag', { fg = c.fg, bold = true })
hi('Delimiter', { fg = c.muted })
hi('SpecialComment', { fg = c.muted, bold = true, italic = true })
hi('Debug', { fg = c.fg })
hi('Underlined', { fg = c.fg, underline = true })
hi('Ignore', { fg = c.subtle })
hi('Error', { fg = c.bright, bold = true, undercurl = true, sp = c.bright })
hi('Todo', { fg = c.bg, bg = c.fg, bold = true })

-- Treesitter (Neovim 0.10-0.12 + nvim-treesitter main captures)
hi('@variable', { fg = c.fg })
hi('@variable.builtin', { fg = c.fg, italic = true })
hi('@variable.parameter', { fg = c.fg, italic = true })
hi('@variable.parameter.builtin', { fg = c.fg, italic = true })
hi('@variable.member', { fg = c.fg })
hi('@constant', { fg = c.fg })
hi('@constant.builtin', { fg = c.fg, bold = true })
hi('@constant.macro', { fg = c.fg, bold = true })
hi('@module', { fg = c.fg })
hi('@module.builtin', { fg = c.fg, italic = true })
hi('@label', { fg = c.fg, bold = true })
hi('@string', { fg = c.fg, italic = true })
hi('@string.documentation', { fg = comment, italic = true })
hi('@string.regexp', { fg = c.fg })
hi('@string.escape', { fg = c.bright, bold = true })
hi('@string.special', { fg = c.fg, bold = true })
hi('@string.special.symbol', { fg = c.fg })
hi('@string.special.url', { fg = c.fg, underline = true })
hi('@string.special.path', { fg = c.fg })
hi('@character', { fg = c.fg })
hi('@character.special', { fg = c.bright, bold = true })
hi('@number', { fg = c.fg })
hi('@number.float', { fg = c.fg })
hi('@boolean', { fg = c.fg, bold = true })
hi('@type', { fg = c.fg, bold = true })
hi('@type.builtin', { fg = c.fg, bold = true })
hi('@type.definition', { fg = c.fg, bold = true })
hi('@attribute', { fg = c.fg, italic = true })
hi('@property', { fg = c.fg })
hi('@function', { fg = c.fg, bold = true })
hi('@function.builtin', { fg = c.fg, bold = true })
hi('@function.call', { fg = c.fg })
hi('@function.macro', { fg = c.fg, bold = true, italic = true })
hi('@function.method', { fg = c.fg, bold = true })
hi('@function.method.call', { fg = c.fg })
hi('@constructor', { fg = c.fg, bold = true })
hi('@operator', { fg = c.muted })
hi('@keyword', { fg = c.bright, bold = true })
hi('@keyword.function', { fg = c.bright, bold = true })
hi('@keyword.coroutine', { fg = c.bright, bold = true })
hi('@keyword.operator', { fg = c.bright, bold = true })
hi('@keyword.import', { fg = c.fg, bold = true })
hi('@keyword.type', { fg = c.bright, bold = true })
hi('@keyword.modifier', { fg = c.fg, bold = true })
hi('@keyword.repeat', { fg = c.bright, bold = true })
hi('@keyword.return', { fg = c.bright, bold = true })
hi('@keyword.debug', { fg = c.bright, bold = true })
hi('@keyword.exception', { fg = c.bright, bold = true })
hi('@keyword.conditional', { fg = c.bright, bold = true })
hi('@keyword.conditional.ternary', { fg = c.muted, bold = true })
hi('@keyword.directive', { fg = c.fg, bold = true })
hi('@keyword.directive.define', { fg = c.fg, bold = true })
hi('@punctuation', { fg = c.muted })
hi('@punctuation.bracket', { fg = c.muted })
hi('@punctuation.delimiter', { fg = c.muted })
hi('@punctuation.special', { fg = c.muted, bold = true })
hi('@comment', { fg = comment, italic = true })
hi('@comment.documentation', { fg = comment, italic = true })
hi('@comment.error', { fg = c.bg, bg = c.bright, bold = true })
hi('@comment.warning', { fg = c.bg, bg = c.secondary, bold = true })
hi('@comment.todo', { fg = c.bg, bg = c.fg, bold = true })
hi('@comment.note', { fg = c.fg, bg = c.visual, bold = true })
hi('@tag', { fg = c.fg, bold = true })
hi('@tag.builtin', { fg = c.fg, bold = true })
hi('@tag.attribute', { fg = c.fg, italic = true })
hi('@tag.delimiter', { fg = c.muted })
hi('@diff.plus', { link = 'Added' })
hi('@diff.minus', { link = 'Removed' })
hi('@diff.delta', { link = 'Changed' })

-- Treesitter Markup & render-markdown.nvim
hi('@markup.strong', { fg = c.bright, bold = true })
hi('@markup.italic', { fg = c.fg, italic = true })
hi('@markup.strikethrough', { fg = c.dim, strikethrough = true })
hi('@markup.underline', { fg = c.fg, underline = true })
hi('@markup.heading', { fg = c.bright, bold = true })
hi('@markup.heading.1', { fg = c.bright, bold = true })
hi('@markup.heading.2', { fg = c.bright, bold = true })
hi('@markup.heading.3', { fg = c.fg, bold = true })
hi('@markup.heading.4', { fg = c.fg, bold = true })
hi('@markup.heading.5', { fg = c.secondary, bold = true })
hi('@markup.heading.6', { fg = c.muted, bold = true })
hi('@markup.quote', { fg = c.muted, italic = true })
hi('@markup.math', { fg = c.secondary })
hi('@markup.link', { fg = c.secondary })
hi('@markup.link.label', { fg = c.secondary, italic = true })
hi('@markup.link.url', { fg = c.muted, underline = true })
hi('@markup.raw', { fg = c.fg, bg = c.visual })
hi('@markup.raw.block', { fg = c.fg })
hi('@markup.list', { fg = c.muted })
hi('@markup.list.checked', { fg = c.fg, bold = true })
hi('@markup.list.unchecked', { fg = c.dim })

hi('RenderMarkdownH1', { fg = c.bright, bold = true })
hi('RenderMarkdownH2', { fg = c.bright, bold = true })
hi('RenderMarkdownH3', { fg = c.fg, bold = true })
hi('RenderMarkdownH4', { fg = c.fg, bold = true })
hi('RenderMarkdownH5', { fg = c.secondary, bold = true })
hi('RenderMarkdownH6', { fg = c.muted, bold = true })
hi('RenderMarkdownH1Bg', { fg = c.bright, bg = c.visual, bold = true })
hi('RenderMarkdownH2Bg', { bg = '#151515', bold = true })
hi('RenderMarkdownH3Bg', { bg = c.cursor, bold = true })
hi('RenderMarkdownH4Bg', { bg = c.cursor, bold = true })
hi('RenderMarkdownH5Bg', { bg = c.cursor, bold = true })
hi('RenderMarkdownH6Bg', { bg = c.cursor, bold = true })
hi('RenderMarkdownCode', { fg = c.secondary, bg = c.float_bg })
hi('RenderMarkdownCodeBorder', { fg = c.muted, bg = c.float_bg })
hi('RenderMarkdownCodeInfo', { fg = c.border, bg = c.float_bg })
hi('RenderMarkdownCodeInline', { fg = c.fg, bg = c.visual })
hi('RenderMarkdownBullet', { fg = c.muted })
hi('RenderMarkdownDash', { fg = c.border })
hi('RenderMarkdownQuote', { fg = c.muted, italic = true })
for i = 1, 6 do
  hi('RenderMarkdownQuote' .. i, { fg = c.muted, italic = true })
end
hi('RenderMarkdownLink', { fg = c.secondary, underline = true })
hi('RenderMarkdownWikiLink', { fg = c.secondary, underline = true })
hi('RenderMarkdownChecked', { fg = c.fg, bold = true })
hi('RenderMarkdownUnchecked', { fg = c.dim })
hi('RenderMarkdownTodo', { fg = c.secondary, bold = true })
hi('RenderMarkdownTableHead', { fg = c.fg, bold = true })
hi('RenderMarkdownTableRow', { fg = c.fg })
hi('RenderMarkdownSuccess', { fg = c.dim })
hi('RenderMarkdownInfo', { fg = c.dim, italic = true })
hi('RenderMarkdownHint', { fg = c.secondary, bold = true })
hi('RenderMarkdownWarn', { fg = c.secondary, bold = true })
hi('RenderMarkdownError', { fg = c.bright, bold = true })

-- LSP Diagnostics
hi('DiagnosticError', { fg = c.bright, bold = true })
hi('DiagnosticWarn', { fg = c.secondary, bold = true })
hi('DiagnosticInfo', { fg = c.muted })
hi('DiagnosticHint', { fg = c.dim, italic = true })
hi('DiagnosticOk', { fg = c.dim })
hi('DiagnosticUnnecessary', { fg = c.dim, italic = true })
hi('DiagnosticDeprecated', { fg = c.dim, strikethrough = true })
hi('DiagnosticUnderlineError', { undercurl = true, sp = c.bright })
hi('DiagnosticUnderlineWarn', { undercurl = true, sp = c.secondary })
hi('DiagnosticUnderlineInfo', { underdotted = true, sp = c.muted })
hi('DiagnosticUnderlineHint', { underdotted = true, sp = c.dim })
hi('DiagnosticUnderlineOk', { underdotted = true, sp = c.dim })
hi('DiagnosticVirtualTextError', { fg = c.bright, bg = c.cursor, bold = true })
hi('DiagnosticVirtualTextWarn', { fg = c.secondary, bg = c.cursor })
hi('DiagnosticVirtualTextInfo', { fg = c.muted, bg = c.cursor })
hi('DiagnosticVirtualTextHint', { fg = c.dim, bg = c.cursor, italic = true })
hi('DiagnosticVirtualTextOk', { fg = c.dim, bg = c.cursor })
hi('DiagnosticFloatingError', { fg = c.bright, bold = true })
hi('DiagnosticFloatingWarn', { fg = c.secondary, bold = true })
hi('DiagnosticFloatingInfo', { fg = c.muted })
hi('DiagnosticFloatingHint', { fg = c.dim, italic = true })
hi('DiagnosticFloatingOk', { fg = c.dim })
hi('DiagnosticSignError', { fg = c.bright, bold = true })
hi('DiagnosticSignWarn', { fg = c.secondary, bold = true })
hi('DiagnosticSignInfo', { fg = c.muted })
hi('DiagnosticSignHint', { fg = c.dim })
hi('DiagnosticSignOk', { fg = c.dim })

-- LSP References, Hints & Semantic Tokens
hi('LspReferenceText', { bg = c.visual })
hi('LspReferenceRead', { bg = c.cursor })
hi('LspReferenceWrite', { bg = c.visual, bold = true })
hi('LspSignatureActiveParameter', { fg = c.bright, bg = c.visual, bold = true })
hi('LspCodeLens', { fg = c.dim, italic = true })
hi('LspCodeLensSeparator', { fg = c.subtle })
hi('LspInlayHint', { fg = c.dim, bg = c.cursor, italic = true })
hi('LspInfoBorder', { fg = c.border, bg = float_bg })

hi('@lsp.type.class', { fg = c.fg, bold = true })
hi('@lsp.type.struct', { fg = c.fg, bold = true })
hi('@lsp.type.interface', { fg = c.fg, bold = true })
hi('@lsp.type.enum', { fg = c.fg, bold = true })
hi('@lsp.type.enumMember', { fg = c.fg })
hi('@lsp.type.parameter', { fg = c.fg, italic = true })
hi('@lsp.type.variable', { fg = c.fg })
hi('@lsp.type.property', { fg = c.fg })
hi('@lsp.type.function', { fg = c.fg, bold = true })
hi('@lsp.type.method', { fg = c.fg, bold = true })
hi('@lsp.type.macro', { fg = c.fg, bold = true })
hi('@lsp.type.keyword', { fg = c.bright, bold = true })
hi('@lsp.type.namespace', { fg = c.fg })
hi('@lsp.type.type', { fg = c.fg, bold = true })
hi('@lsp.type.typeParameter', { fg = c.fg, italic = true })
hi('@lsp.type.operator', { fg = c.muted })
hi('@lsp.mod.defaultLibrary', { italic = true })
hi('@lsp.mod.deprecated', { strikethrough = true })

-- GitSigns (including staged variants so gitsigns doesn't halve RGB into invisible grays)
hi('GitSignsAdd', { fg = c.fg })
hi('GitSignsChange', { fg = c.muted })
hi('GitSignsDelete', { fg = c.bright })
hi('GitSignsStagedAdd', { fg = c.dim })
hi('GitSignsStagedChange', { fg = c.dim })
hi('GitSignsStagedDelete', { fg = c.subtle })
hi('GitSignsCurrentLineBlame', { fg = c.dim, italic = true })
hi('GitSignsAddPreview', { link = 'DiffAdd' })
hi('GitSignsDeletePreview', { link = 'DiffDelete' })
hi('GitSignsAddInline', { fg = c.bright, bg = c.visual, bold = true })
hi('GitSignsDeleteInline', { fg = c.dim, bg = '#241414', strikethrough = true })
hi('GitSignsChangeInline', { bg = c.visual })

-- fzf-lua (overrides default pink/green/ANSI highlights)
hi('FzfLuaNormal', { fg = c.fg, bg = float_bg })
hi('FzfLuaBorder', { fg = c.border, bg = float_bg })
hi('FzfLuaTitle', { fg = c.bg, bg = c.fg, bold = true })
hi('FzfLuaPreviewNormal', { fg = c.fg, bg = float_bg })
hi('FzfLuaPreviewBorder', { fg = c.border, bg = float_bg })
hi('FzfLuaPreviewTitle', { fg = c.bg, bg = c.muted, bold = true })
hi('FzfLuaCursorLine', { bg = c.visual, bold = true })
hi('FzfLuaScrollBorderEmpty', { fg = c.border, bg = float_bg })
hi('FzfLuaScrollBorderFull', { fg = c.muted, bg = float_bg })
hi('FzfLuaScrollFloatEmpty', { bg = c.cursor })
hi('FzfLuaScrollFloatFull', { bg = c.dim })
hi('FzfLuaHeaderBind', { fg = c.secondary, bold = true })
hi('FzfLuaHeaderText', { fg = c.muted })
hi('FzfLuaPathColNr', { fg = c.dim })
hi('FzfLuaPathLineNr', { fg = c.dim })
hi('FzfLuaBufName', { fg = c.muted })
hi('FzfLuaBufId', { fg = c.fg })
hi('FzfLuaBufNr', { fg = c.dim })
hi('FzfLuaBufLineNr', { fg = c.muted })
hi('FzfLuaBufFlagCur', { fg = c.dim })
hi('FzfLuaBufFlagAlt', { fg = c.bright, bold = true })
hi('FzfLuaTabTitle', { fg = c.muted })
hi('FzfLuaTabMarker', { fg = c.bright, bold = true })
hi('FzfLuaDirIcon', { fg = c.secondary, bold = true })
hi('FzfLuaDirPart', { fg = c.dim })
hi('FzfLuaFilePart', { fg = c.fg })
hi('FzfLuaLivePrompt', { fg = c.bright, bold = true })
hi('FzfLuaLiveSym', { fg = c.bright, bold = true })
hi('FzfLuaFzfNormal', { fg = c.fg, bg = float_bg })
hi('FzfLuaFzfCursorLine', { fg = c.bright, bg = c.visual, bold = true })
hi('FzfLuaFzfMatch', { fg = c.bright, bold = true })
hi('FzfLuaFzfBorder', { fg = c.border, bg = float_bg })
hi('FzfLuaFzfScrollbar', { fg = c.dim, bg = float_bg })
hi('FzfLuaFzfSeparator', { fg = c.border, bg = float_bg })
hi('FzfLuaFzfGutter', { bg = float_bg })
hi('FzfLuaFzfHeader', { fg = c.muted })
hi('FzfLuaFzfInfo', { fg = c.muted })
hi('FzfLuaFzfPointer', { fg = c.bright, bold = true })
hi('FzfLuaFzfMarker', { fg = c.bright, bold = true })
hi('FzfLuaFzfSpinner', { fg = c.secondary })
hi('FzfLuaFzfPrompt', { fg = c.fg, bold = true })
hi('FzfLuaFzfQuery', { fg = c.bright })

-- flash.nvim (distinct jump label vs search match)
hi('FlashBackdrop', { fg = c.dim })
hi('FlashMatch', { fg = c.fg, bg = c.visual })
hi('FlashCurrent', { fg = c.bg, bg = c.secondary, bold = true })
hi('FlashLabel', { fg = c.bg, bg = c.bright, bold = true })
hi('FlashPrompt', { fg = c.fg, bg = surface_bg })
hi('FlashPromptIcon', { fg = c.bright, bold = true })

-- nvim-notify & noice.nvim (overrides hardcoded #F70067 / #F79000 / #A9FF68 / #D484FF)
for level, spec in pairs({
  ERROR = { fg = c.bright, border = c.muted, bold = true },
  WARN  = { fg = c.secondary, border = c.dim, bold = true },
  INFO  = { fg = c.fg, border = c.border, bold = false },
  DEBUG = { fg = c.dim, border = c.border, bold = false },
  TRACE = { fg = c.dim, border = c.border, bold = false },
}) do
  hi('Notify' .. level .. 'Border', { fg = spec.border, bg = float_bg })
  hi('Notify' .. level .. 'Icon', { fg = spec.fg, bg = float_bg, bold = spec.bold })
  hi('Notify' .. level .. 'Title', { fg = spec.fg, bg = float_bg, bold = true })
  hi('Notify' .. level .. 'Body', { fg = spec.fg, bg = float_bg })
end
hi('NotifyBackground', { bg = c.bg })

hi('NoiceCmdline', { fg = c.fg, bg = float_bg })
hi('NoiceCmdlinePopup', { fg = c.fg, bg = float_bg })
hi('NoiceCmdlinePopupBorder', { fg = c.border, bg = float_bg })
hi('NoiceCmdlinePopupTitle', { fg = c.fg, bg = float_bg, bold = true })
hi('NoiceCmdlineIcon', { fg = c.bright, bold = true })
hi('NoiceCmdlineIconSearch', { fg = c.bright, bold = true })
hi('NoiceConfirm', { fg = c.fg, bg = float_bg })
hi('NoiceConfirmBorder', { fg = c.border, bg = float_bg })
hi('NoicePopup', { fg = c.fg, bg = float_bg })
hi('NoicePopupBorder', { fg = c.border, bg = float_bg })
hi('NoicePopupmenu', { link = 'Pmenu' })
hi('NoicePopupmenuBorder', { fg = c.border, bg = c.float_bg })
hi('NoiceScrollbar', { bg = c.float_bg })
hi('NoiceScrollbarThumb', { bg = c.dim })
hi('NoiceSplit', { fg = c.fg, bg = surface_bg })
hi('NoiceSplitBorder', { fg = c.border, bg = 'NONE' })
hi('NoiceVirtualText', { fg = c.dim, italic = true })
hi('NoiceFormatProgressDone', { fg = c.bg, bg = c.fg, bold = true })
hi('NoiceFormatProgressTodo', { fg = c.dim, bg = c.cursor })

-- lspsaga (overrides hardcoded crimson SagaBeacon & gray SagaCount)
hi('SagaNormal', { fg = c.fg, bg = float_bg })
hi('SagaBorder', { fg = c.border, bg = float_bg })
hi('SagaTitle', { fg = c.fg, bg = float_bg, bold = true })
hi('SagaBeacon', { bg = c.visual })
hi('SagaVirtLine', { fg = c.subtle })
hi('SagaCount', { fg = c.bg, bg = c.muted, bold = true })

-- blink.cmp & nvim-cmp
hi('BlinkCmpMenu', { fg = c.fg, bg = c.float_bg })
hi('BlinkCmpScrollBarGutter', { bg = c.float_bg })
hi('BlinkCmpScrollBarThumb', { bg = c.dim })
hi('BlinkCmpLabel', { fg = c.fg })
hi('BlinkCmpLabelDeprecated', { fg = c.dim, strikethrough = true })
hi('BlinkCmpLabelMatch', { fg = c.bright, bold = true })
hi('BlinkCmpLabelDetail', { fg = c.dim })
hi('BlinkCmpLabelDescription', { fg = c.dim, italic = true })
hi('BlinkCmpKind', { fg = c.muted })
hi('BlinkCmpSource', { fg = c.dim, italic = true })
hi('BlinkCmpGhostText', { fg = c.dim, italic = true })
hi('BlinkCmpDoc', { fg = c.fg, bg = float_bg })
hi('BlinkCmpDocBorder', { fg = c.border, bg = float_bg })
hi('BlinkCmpDocSeparator', { fg = c.border, bg = float_bg })
hi('BlinkCmpDocCursorLine', { bg = c.cursor })
hi('BlinkCmpSignatureHelp', { fg = c.fg, bg = float_bg })
hi('BlinkCmpSignatureHelpBorder', { fg = c.border, bg = float_bg })
hi('BlinkCmpSignatureHelpActiveParameter', { fg = c.bright, bg = c.visual, bold = true })

hi('CmpItemAbbr', { fg = c.fg })
hi('CmpItemAbbrMatch', { fg = c.bright, bold = true })
hi('CmpItemAbbrMatchFuzzy', { fg = c.bright, bold = true })
hi('CmpItemAbbrDeprecated', { fg = c.dim, strikethrough = true })
hi('CmpItemKind', { fg = c.muted })
hi('CmpItemMenu', { fg = c.dim, italic = true })
for _, kind in ipairs({
  'Text', 'Variable', 'Color', 'File', 'Reference', 'Value', 'Unit',
  'Constant', 'Field', 'Property', 'Module', 'EnumMember', 'Event', 'Operator',
}) do
  hi('CmpItemKind' .. kind, { fg = c.dim })
end
for _, kind in ipairs({
  'Method', 'Function', 'Keyword', 'Folder', 'Constructor', 'Class', 'Interface', 'Enum', 'Struct',
}) do
  hi('CmpItemKind' .. kind, { fg = c.muted, bold = true })
end
hi('CmpItemKindSnippet', { fg = c.dim, italic = true })
hi('CmpItemKindTypeParameter', { fg = c.dim, italic = true })

-- Telescope (fixed selection contrast against float_bg)
hi('TelescopeNormal', { fg = c.fg, bg = float_bg })
hi('TelescopeBorder', { fg = c.border, bg = float_bg })
hi('TelescopePromptNormal', { fg = c.fg, bg = float_bg })
hi('TelescopePromptBorder', { fg = c.border, bg = float_bg })
hi('TelescopePromptTitle', { fg = c.bg, bg = c.fg, bold = true })
hi('TelescopePreviewTitle', { fg = c.bg, bg = c.muted, bold = true })
hi('TelescopeResultsTitle', { fg = c.bg, bg = c.muted, bold = true })
hi('TelescopeSelection', { fg = c.bright, bg = c.visual, bold = true })
hi('TelescopeSelectionCaret', { fg = c.bright, bg = c.visual, bold = true })
hi('TelescopeMatching', { fg = c.bright, bold = true })
hi('TelescopePromptPrefix', { fg = c.fg, bold = true })

-- Terminal ANSI palette (stepped mid-grays avoid white-on-white TUI pill collisions in yazi/git)
vim.g.terminal_color_0  = c.bg
vim.g.terminal_color_1  = '#A8A8A8'
vim.g.terminal_color_2  = c.muted
vim.g.terminal_color_3  = c.secondary
vim.g.terminal_color_4  = '#787878'
vim.g.terminal_color_5  = '#888888'
vim.g.terminal_color_6  = '#A0A0A0'
vim.g.terminal_color_7  = c.fg
vim.g.terminal_color_8  = c.dim
vim.g.terminal_color_9  = c.bright
vim.g.terminal_color_10 = '#D0D0D0'
vim.g.terminal_color_11 = c.muted
vim.g.terminal_color_12 = c.secondary
vim.g.terminal_color_13 = c.fg
vim.g.terminal_color_14 = '#C8C8C8'
vim.g.terminal_color_15 = c.bright

-- Standalone monotone icon & optional OSC 12 cursor sync
-- (replaces mfd.override_icons / enable cursor_sync)
local augroup           = vim.api.nvim_create_augroup('CrackColorscheme', { clear = true })

local function apply_monotone_icons()
  if vim.g.colors_name ~= 'crack' then return end

  for _, color in ipairs({ 'Blue', 'Green', 'Cyan', 'Grey', 'Orange', 'Purple', 'Red', 'Yellow', 'Azure' }) do
    vim.api.nvim_set_hl(0, 'MiniIcons' .. color, { fg = c.dim })
  end

  for _, grp in ipairs({
    'NvimTreeFolderIcon',
    'NvimTreeOpenedFolderIcon',
    'NvimTreeFileIcon',
    'NvimTreeSpecialFile',
  }) do
    vim.api.nvim_set_hl(0, grp, { fg = c.dim })
  end

  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if ok then
    local def = devicons.get_default_icon and devicons.get_default_icon() or {}
    devicons.set_default_icon(def.icon or '', c.dim)
    local icons = devicons.get_icons()
    local overrides = {}
    for key, icon in pairs(icons) do
      overrides[key] = { icon = icon.icon, color = c.dim, name = icon.name }
    end
    pcall(devicons.set_icon, overrides)
  end
end

apply_monotone_icons()
vim.api.nvim_create_autocmd('VimEnter', {
  group = augroup,
  callback = function()
    vim.schedule(apply_monotone_icons)
  end,
})

if cfg.cursor_sync then
  local mode_hl = {
    n = 'CursorNormal',
    i = 'CursorInsert',
    v = 'CursorVisual',
    V = 'CursorVisual',
    ['\22'] = 'CursorVisual',
    R = 'CursorReplace',
    c = 'CursorCommand',
  }

  local function osc(seq)
    if vim.env.TMUX then
      io.write('\027Ptmux;\027' .. seq .. '\027\\')
    else
      io.write(seq)
    end
  end

  local function sync_cursor()
    if vim.g.colors_name ~= 'crack' then return end
    local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
    local hl = vim.api.nvim_get_hl(0, { name = mode_hl[mode] or 'CursorNormal' })
    if hl.bg then
      osc(string.format('\027]12;#%06x\007', hl.bg))
    end
  end

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = augroup,
    pattern = '*',
    callback = sync_cursor,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function() osc('\027]112\007') end,
  })
  sync_cursor()
end
