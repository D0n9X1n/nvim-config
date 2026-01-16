-- ====================================================================
-- Theme Settings
-- ====================================================================

local opt = vim.opt
local g = vim.g

-- Background
opt.background = 'dark'

-- Gruvbox settings
g.gruvbox_contrast_dark = 'light'
g.gruvbox_improved_warnings = 1
g.gruvbox_sign_column = 'bg0'

-- Set colorscheme (ensure gruvbox is installed via lazy.nvim)
pcall(function()
  vim.cmd('colorscheme gruvbox')
end)

-- Match sign column background to line number column
vim.cmd('hi! link SignColumn LineNr')
vim.cmd('hi! link ShowMarksHLl DiffAdd')
vim.cmd('hi! link ShowMarksHLu DiffChange')

-- LSP diagnostics: red text + underline + virtual text for errors.
vim.cmd('hi! DiagnosticError ctermfg=Red guifg=Red')
vim.cmd('hi! DiagnosticUnderlineError cterm=underline gui=underline ctermfg=Red guisp=Red')
vim.cmd('hi! DiagnosticVirtualTextError ctermfg=Red guifg=Red')
vim.cmd('hi! DiagnosticSignError ctermfg=Red guifg=Red')
vim.cmd('hi! LspDiagnosticsDefaultError ctermfg=Red guifg=Red')
vim.cmd('hi! LspDiagnosticsUnderlineError cterm=underline gui=underline ctermfg=Red guisp=Red')
vim.cmd('hi! LspDiagnosticsVirtualTextError ctermfg=Red guifg=Red')
vim.cmd('hi! LspDiagnosticsSignError ctermfg=Red guifg=Red')

-- LSP diagnostics: orange warnings.
vim.cmd('hi! DiagnosticWarn ctermfg=208 guifg=#ff8800')
vim.cmd('hi! DiagnosticUnderlineWarn cterm=underline gui=underline ctermfg=208 guisp=#ff8800')
vim.cmd('hi! DiagnosticVirtualTextWarn ctermfg=208 guifg=#ff8800')
vim.cmd('hi! DiagnosticSignWarn ctermfg=208 guifg=#ff8800')
vim.cmd('hi! LspDiagnosticsDefaultWarning ctermfg=208 guifg=#ff8800')
vim.cmd('hi! LspDiagnosticsUnderlineWarning cterm=underline gui=underline ctermfg=208 guisp=#ff8800')
vim.cmd('hi! LspDiagnosticsVirtualTextWarning ctermfg=208 guifg=#ff8800')
vim.cmd('hi! LspDiagnosticsSignWarning ctermfg=208 guifg=#ff8800')


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
  opt.guifont = 'FiraCode Nerd Font:h14.5'
  pcall(function()
    vim.cmd('colorscheme solarized8_flat')
  end)
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
