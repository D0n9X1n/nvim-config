-- ====================================================================
-- Additional Plugin Configurations
-- ====================================================================

local g = vim.g
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- NerdCommenter
g.NERDSpaceDelims = 1
g.NERDCustomDelimiters = {
  c = { left = '/*', right = '*/' },
  cpp = { left = '/*', right = '*/' }
}

-- CtrlP
g.ctrlp_map = '<leader>p'
g.ctrlp_cmd = 'CtrlP'
g.ctrlp_custom_ignore = {
  dir = [[^\v[\/](\.(git|hg|svn|rvm|)|node_modules)$]],
  file = [[^\v\.(exe|so|dll|zip|tar|tar.gz|pyc)$]],
}
g.ctrlp_working_path_mode = 0
g.ctrlp_match_window_bottom = 1
g.ctrlp_max_height = 15
g.ctrlp_follow_symlinks = 1

if vim.fn.executable('ag') == 1 then
  g.ctrlp_user_command = 'ag %s -l --nocolor -g ""'
  g.ctrlp_use_caching = 0
end

g.ctrlp_funky_syntax_highlight = 1
g.ctrlp_extensions = { 'funky' }

-- CtrlSF
g.ctrlsf_auto_close = 0
g.ctrlsf_confirm_save = 0
g.ctrlsf_mapping = {
  open = '<Space>',
  openb = 'O',
  tab = 't',
  quit = 'q',
  next = '<C-J>',
  prev = '<C-K>'
}

-- GitGutter
g.gitgutter_map_keys = 0
g.gitgutter_enabled = 0
g.gitgutter_highlight_lines = 1

-- NERDTree
g.NERDTreeIgnore = {
  '\\.pyc$', '\\.o$', '\\.egg$', '^\\.git$', '^\\.svn$', '^\\.hg$', 'tags',
  '\\.test$', '\\.dSYM$', '\\.a$', '\\.so$'
}
g.NERDTreeMapOpenSplit = 's'
g.NERDTreeMapOpenVSplit = 'v'
g.NERDTreeWinSize = 25

-- NERDTree Tabs
g.nerdtree_tabs_synchronize_view = 1
g.nerdtree_tabs_synchronize_focus = 1
g.nerdtree_tabs_open_on_console_startup = 0
g.nerdtree_tabs_open_on_gui_startup = 0

-- Tagbar
g.tagbar_autofocus = 1
g.tagbar_width = 35

-- EasyMotion
g.EasyMotion_smartcase = 1

-- QuickScope
g.qs_highlight_on_keys = { 'f', 'F', 't', 'T' }

-- Multiple Cursors
g.multi_cursor_use_default_mapping = 0
g.multi_cursor_next_key = '<C-d>'
g.multi_cursor_prev_key = '<C-p>'
g.multi_cursor_skip_key = '<C-j>'
g.multi_cursor_quit_key = '<Esc>'

-- IndentLine
g.markdown_syntax_conceal = 0
g.vim_markdown_conceal_code_blocks = 0
g.vim_markdown_conceal = 0
g.indentLine_enabled = 1

-- Rainbow Parentheses
g.rainbow_active = 1
g.rainbow_conf = {
  guifgs = { 'royalblue3', 'darkorange3', 'seagreen3', 'firebrick' },
  ctermfgs = { 'darkblue', 'darkyellow', 'darkcyan', 'darkmagenta', 'darkgreen', 'darkred' }
}

-- Autoformat
g.autoformat_verbosemode = 0

-- Emmet
g.user_emmet_install_global = 0
