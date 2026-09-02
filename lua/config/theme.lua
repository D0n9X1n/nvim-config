-- ====================================================================
-- Theme Settings
-- ====================================================================

local opt = vim.opt
local g = vim.g

-- Background
opt.background = 'dark'

-- Everforest settings (kept for reference)
g.everforest_background = 'medium'
g.everforest_better_performance = 1

-- Set colorscheme
pcall(function()
  vim.cmd.colorscheme('apollo')
end)

-- Match sign column background to line number column
vim.cmd('hi! link SignColumn LineNr')
vim.cmd('hi! link ShowMarksHLl DiffAdd')
vim.cmd('hi! link ShowMarksHLu DiffChange')

local function apply_diagnostic_highlights()
  local error_color = '#ff3b30'
  local warning_color = '#ff9f0a'

  for _, group in ipairs({ 'DiagnosticError', 'DiagnosticVirtualTextError', 'DiagnosticSignError', 'DiagnosticFloatingError' }) do
    vim.api.nvim_set_hl(0, group, { fg = error_color, ctermfg = 196 })
  end
  vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', {
    fg = error_color,
    sp = error_color,
    undercurl = true,
    ctermfg = 196,
    underline = true,
  })

  for _, group in ipairs({ 'DiagnosticWarn', 'DiagnosticVirtualTextWarn', 'DiagnosticSignWarn', 'DiagnosticFloatingWarn' }) do
    vim.api.nvim_set_hl(0, group, { fg = warning_color, ctermfg = 208 })
  end
  vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', {
    fg = warning_color,
    sp = warning_color,
    undercurl = true,
    ctermfg = 208,
    underline = true,
  })
end

apply_diagnostic_highlights()

vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('DiagnosticHighlights', { clear = true }),
  callback = apply_diagnostic_highlights,
})


-- Softer spell-check highlights
vim.cmd([[
highlight clear SpellBad
highlight SpellBad   term=standout ctermfg=1 term=underline cterm=underline
highlight clear SpellCap
highlight SpellCap   term=underline cterm=underline
highlight clear SpellRare
highlight SpellRare  term=underline cterm=underline
highlight clear SpellLocal
highlight SpellLocal term=underline cterm=underline
]])

-- Cursor settings (terminal)
vim.cmd([[
let &t_SI.="\e[5 q" "SI = INSERT mode
let &t_SR.="\e[4 q" "SR = REPLACE mode
let &t_EI.="\e[1 q" "EI = NORMAL mode (ELSE)
]])

-- GUI-specific settings
if vim.fn.has('gui_running') == 1 then
  opt.guifont = 'Rec Mono St.Helens:h14'
end

-- XTerm paste support
vim.cmd([[
let &t_SI .= "\<Esc>[?2004h"
let &t_EI .= "\<Esc>[?2004l"

inoremap <special> <expr> <Esc>[200~ XTermPasteBegin()

function! XTermPasteBegin()
    set pastetoggle=<Esc>[201~
    set paste
    return ""
endfunction
]])
