-- ====================================================================
-- Lualine Configuration
-- ====================================================================

local function pl_wrap(text)
  return (' %s '):format(text)
end

local function pl_prefix(symbol, text)
  if text == '' then
    return ''
  end
  return ('%s %s'):format(symbol, text)
end

require('lualine').setup({
  options = {
    icons_enabled = false,
    theme = 'auto',
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = { 'NvimTree' },
    },
    always_divide_middle = true,
  },
  sections = {
    lualine_a = { { 'mode', fmt = pl_wrap } },
    lualine_b = {
      { 'branch', fmt = function(text) return pl_prefix('', text) end },
      {
        'diff',
        symbols = { added = '+', modified = '~', removed = '-' },
      },
      {
        'diagnostics',
        symbols = { error = 'E ', warn = 'W ', info = 'I ', hint = 'H ' },
      },
    },
    lualine_c = { { 'filename', path = 1, fmt = pl_wrap } },
    lualine_x = {
      { 'encoding', fmt = function(text) return pl_prefix('', text) end },
      { 'fileformat', fmt = function(text) return pl_prefix('', text) end },
      { 'filetype', fmt = function(text) return pl_prefix('', text) end },
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {},
  },
})
