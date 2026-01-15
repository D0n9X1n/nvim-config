-- ====================================================================
-- UltiSnips Configuration
-- ====================================================================

local g = vim.g

g.UltiSnipsExpandTrigger = '<tab>'
g.UltiSnipsJumpForwardTrigger = '<tab>'
g.UltiSnipsJumpBackwardTrigger = '<s-tab>'
g.UltiSnipsSnippetDirectories = { 'UltiSnips' }
g.UltiSnipsSnippetsDir = vim.fn.expand('~/.config/nvim/snippets')

-- Helper functions for YCM integration
function _G.J_in_YCM()
  if vim.fn.pumvisible() == 1 then
    return vim.api.nvim_replace_termcodes('<C-n>', true, true, true)
  else
    return vim.api.nvim_replace_termcodes('<C-j>', true, true, true)
  end
end

function _G.K_in_YCM()
  if vim.fn.pumvisible() == 1 then
    return vim.api.nvim_replace_termcodes('<C-p>', true, true, true)
  else
    return vim.api.nvim_replace_termcodes('<C-k>', true, true, true)
  end
end

vim.keymap.set('i', '<c-j>', 'v:lua.J_in_YCM()', { expr = true })
vim.keymap.set('i', '<c-k>', 'v:lua.K_in_YCM()', { expr = true })
