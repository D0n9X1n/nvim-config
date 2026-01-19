-- ====================================================================
-- Lualine Configuration
-- ====================================================================

require('lualine').setup({
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = { 'neo-tree' },
    },
    always_divide_middle = true,
  },
  sections = {
    lualine_a = { { 'mode' } },
    lualine_b = {
      { 'branch', icon = '' },
      {
        'diff',
        symbols = { added = ' ', modified = ' ', removed = ' ' },
      },
      {
        'diagnostics',
        symbols = { error = ' ', warn = ' ', info = ' ', hint = '󰌵 ' },
      },
    },
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = {
      { 'encoding', icon = '' },
      { 'fileformat', icon = '' },
      { 'filetype', icon = '󰈔' },
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
