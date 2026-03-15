-- ====================================================================
-- indentmini Configuration
-- ====================================================================

require('indentmini').setup({
  char = '╎',
  minlevel = 2,
  exclude = {
    'help',
    'neo-tree',
    'lazy',
    'mason',
    'dashboard',
    'terminal',
  },
})

-- Subtle colors for gruvbox dark hard (#1d2021 background)
-- Set via autocmd so colorscheme changes don't override them
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    vim.api.nvim_set_hl(0, 'IndentLine', { fg = '#665c54' })
    vim.api.nvim_set_hl(0, 'IndentLineCurrent', { fg = '#7c6f64' })
  end,
})
vim.api.nvim_set_hl(0, 'IndentLine', { fg = '#665c54' })
vim.api.nvim_set_hl(0, 'IndentLineCurrent', { fg = '#7c6f64' })
