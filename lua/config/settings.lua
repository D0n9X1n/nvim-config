-- ====================================================================
-- General Settings
-- ====================================================================

local opt = vim.opt
local g = vim.g

-- Syntax highlighting
vim.cmd('syntax on')

-- Command history size
opt.history = 1000

-- Auto-reload files changed outside Vim
opt.autoread = true

-- Reduce startup messages
opt.shortmess = 'atI'

-- Backups & swap files
opt.backup = false
opt.swapfile = false

-- Wildmenu settings
opt.wildignore = '*.swp,*.bak,*.pyc,*.class,.svn,tags'
opt.wildmode = 'list:longest'

-- Display settings
opt.ruler = true
opt.showcmd = true
opt.showmode = true
opt.scrolloff = 15
opt.number = true
opt.wrap = false
opt.showmatch = true
opt.matchtime = 2
opt.laststatus = 2
opt.cursorline = true

-- Search behavior
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Indentation settings
opt.smartindent = true
opt.autoindent = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.smarttab = true
opt.expandtab = true
opt.shiftround = true

-- Allow hidden buffers
opt.hidden = true

-- Terminal settings
opt.ttyfast = true
opt.mouse = 'a'

-- Line number settings
opt.relativenumber = false
opt.number = true

-- File encoding
opt.encoding = 'utf-8'
opt.fileencodings = 'ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1'
opt.fileformats = 'unix,dos,mac'

-- Format options
opt.formatoptions:append('m')
opt.formatoptions:append('B')

-- Completion behavior
opt.completeopt = 'menu,menuone,longest'
opt.pumheight = 10

-- Folding
opt.foldenable = true
opt.foldmethod = 'indent'
opt.foldlevel = 99

-- Misc settings
opt.backspace = 'eol,start,indent'
opt.whichwrap:append('<,>,h,l')
opt.title = true
opt.magic = true
opt.visualbell = false
opt.errorbells = false
opt.modifiable = true
opt.selection = 'inclusive'
opt.selectmode = 'mouse,key'

-- Color column
opt.colorcolumn = '120'

-- Terminal colors
if vim.fn.has('termguicolors') == 1 then
  opt.termguicolors = true
end

-- Statusline
opt.statusline = '%<%f %h%m%r%=%k[%{(&fenc==\"\")?&enc:&fenc}%{(&bomb?\",BOM\":\"\")}] %-14.(%l,%c%V%) %P'

-- Cinoptions for C/C++
opt.cinoptions:append('g0')

-- Bracket pairing (can be enhanced with plugin delimitMate or nvim-autopairs)
g.closetag_html_style = 1
