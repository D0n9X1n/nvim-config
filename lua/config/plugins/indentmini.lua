-- ====================================================================
-- indentmini Configuration
-- ====================================================================

-- Disabled by default to avoid lag on large files (e.g. C++).
-- Toggle on demand with <leader>il or <F8>.
vim.g.indentmini_enabled = false

local function set_highlights()
  vim.api.nvim_set_hl(0, 'IndentLine', { fg = '#665c54' })
  vim.api.nvim_set_hl(0, 'IndentLineCurrent', { fg = '#7c6f64' })
end

vim.api.nvim_create_autocmd('ColorScheme', { callback = set_highlights })

local M = {}

function M.enable()
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
  set_highlights()
  vim.g.indentmini_enabled = true
end

function M.disable()
  vim.g.indentmini_enabled = false
  vim.cmd('highlight clear IndentLine')
  vim.cmd('highlight clear IndentLineCurrent')
end

function M.toggle()
  if vim.g.indentmini_enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
