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
