#!/usr/bin/env bash
# scripts/smoke.sh — lazy-loading smoke matrix
set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

# Run nvim headless with a Lua predicate. Predicate must call
# vim.cmd('cq') to fail. Returns 0 on pass, non-zero on fail.
nvim_probe() {
  local desc="$1"; shift
  if nvim --headless -u init.lua "$@" +qa 2>/dev/null; then
    ok "$desc"
  else
    bad "$desc"
  fi
}

# is the plugin's lazy.nvim record marked loaded?
loaded_lua() {
  local name="$1"
  printf %s "local p=require('lazy.core.config').plugins['$name']; if not (p and p._.loaded) then vim.cmd('cq') end"
}
not_loaded_lua() {
  local name="$1"
  printf %s "local p=require('lazy.core.config').plugins['$name']; if not p then vim.cmd('cq') end; if p._.loaded then vim.cmd('cq') end"
}

assert_not_eager()       { nvim_probe "$1 not eager"            +"lua $(not_loaded_lua "$1")"; }
assert_loads_on_ft()     { nvim_probe "$1 loads on ft=$2"       +"silent! e scratch.$2" +"lua $(loaded_lua "$1")"; }
assert_loads_on_ft_explicit() { nvim_probe "$1 loads on ft=$2" +"e scratch" +"set filetype=$2" +"lua $(loaded_lua "$1")"; }
assert_loads_on_cmd()    { nvim_probe "$1 loads on :$2"         +"silent! $2"   +"lua $(loaded_lua "$1")"; }
assert_loads_on_event()  { nvim_probe "$1 loads on $2"          +"doautocmd $2" +"lua $(loaded_lua "$1")"; }
assert_loads_on_insert() { nvim_probe "$1 loads on InsertEnter" +"doautocmd InsertEnter"  +"lua $(loaded_lua "$1")"; }

echo "== smoke matrix =="
# rows are appended by later tasks (insert above this marker)
assert_not_eager typescript-vim
assert_not_eager vim-javascript
assert_not_eager vim-graphql
assert_not_eager yats.vim
assert_not_eager tsuquyomi
assert_not_eager vim-solidity
assert_loads_on_ft typescript-vim ts
assert_loads_on_ft vim-javascript  js
assert_loads_on_ft vim-graphql     graphql
assert_loads_on_ft yats.vim        ts
assert_loads_on_ft tsuquyomi       ts
assert_loads_on_ft vim-solidity    sol
assert_not_eager typescript-tools.nvim
assert_loads_on_ft typescript-tools.nvim ts
assert_not_eager nvim-lspconfig
nvim_probe "nvim-lspconfig loads on BufReadPre" +"e README.md" +"lua $(loaded_lua nvim-lspconfig)"
assert_not_eager nvim-cmp
assert_loads_on_insert nvim-cmp
assert_not_eager nvim-treesitter
nvim_probe "nvim-treesitter loads on BufReadPost" +"e README.md" +"lua $(loaded_lua nvim-treesitter)"
assert_not_eager delimitMate
assert_loads_on_insert delimitMate
assert_not_eager closetag.vim
assert_loads_on_ft closetag.vim html
assert_loads_on_ft_explicit closetag.vim javascriptreact
assert_loads_on_ft_explicit closetag.vim typescriptreact
assert_not_eager indentmini.nvim
nvim_probe "indentmini.nvim loads on BufReadPost" +"e README.md" +"lua $(loaded_lua indentmini.nvim)"
assert_not_eager vim-easy-align
nvim_probe "vim-easy-align registers :EasyAlign lazy cmd" +"lua if not vim.api.nvim_get_commands({})['EasyAlign'] then vim.cmd('cq') end"
for p in nerdcommenter vim-repeat rainbow quick-scope vim-multiple-cursors todo-comments.nvim; do
  assert_not_eager "$p"
done
nvim_probe "nerdcommenter loads on BufReadPost"     +"e README.md" +"lua $(loaded_lua nerdcommenter)"
nvim_probe "vim-repeat loads on BufReadPost"        +"e README.md" +"lua $(loaded_lua vim-repeat)"
nvim_probe "rainbow loads on BufReadPost"           +"e README.md" +"lua $(loaded_lua rainbow)"
nvim_probe "quick-scope loads on BufReadPost"       +"e README.md" +"lua $(loaded_lua quick-scope)"
nvim_probe "vim-multiple-cursors loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-multiple-cursors)"
nvim_probe "todo-comments loads on BufReadPost"     +"e README.md" +"lua $(loaded_lua todo-comments.nvim)"
assert_not_eager vim-easymotion
nvim_probe "vim-easymotion loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-easymotion)"
assert_not_eager nvim-colorizer.lua
nvim_probe "colorizer loads on BufReadPost" +"e README.md" +"lua $(loaded_lua nvim-colorizer.lua)"
assert_not_eager nvim-emmet
assert_loads_on_ft nvim-emmet html
for p in tagbar vim-trailing-whitespace vim-easygrep ag.vim; do
  assert_not_eager "$p"
done
assert_loads_on_cmd tagbar TagbarOpen
assert_loads_on_cmd vim-trailing-whitespace FixWhitespace
assert_loads_on_cmd vim-easygrep            GrepBuffer
assert_loads_on_cmd ag.vim                  "AgFromSearch"
assert_not_eager ctrlsf.vim
assert_loads_on_cmd ctrlsf.vim CtrlSFToggle
assert_not_eager telescope.nvim
assert_loads_on_cmd telescope.nvim "Telescope find_files"
assert_not_eager neo-tree.nvim
assert_loads_on_cmd neo-tree.nvim "Neotree close"
assert_not_eager vim-fugitive
assert_loads_on_cmd vim-fugitive "Git status"
assert_not_eager vim-gitgutter
nvim_probe "gitgutter loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-gitgutter)"
assert_not_eager gundo.vim
assert_not_eager quickrun.vim
assert_not_eager vim-autoformat
assert_loads_on_cmd gundo.vim      GundoToggle
assert_loads_on_cmd quickrun.vim   QuickRun
assert_loads_on_cmd vim-autoformat Autoformat
assert_not_eager wilder.nvim
nvim_probe "wilder loads on CmdlineEnter" +"doautocmd CmdlineEnter" +"lua $(loaded_lua wilder.nvim)"
assert_not_eager editorconfig.nvim
nvim_probe "editorconfig loads on BufReadPre" +"e README.md" +"lua $(loaded_lua editorconfig.nvim)"
assert_not_eager vim-solarized8
assert_not_eager base16-vim
assert_not_eager everforest
assert_not_eager ayu-vim
assert_not_eager NeoSolarized.nvim
nvim_probe "gruvbox is eager (loaded at startup)" +"lua $(loaded_lua gruvbox)"
nvim_probe "gruvbox has priority = 1000" +"lua local p=require('lazy.core.config').plugins['gruvbox']; if not (p and p.priority == 1000) then vim.cmd('cq') end"

echo
echo "== Intentionally eager (kept eager per user decision) =="
nvim_probe "lualine.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua lualine.nvim)"
nvim_probe "bufferline.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua bufferline.nvim)"
nvim_probe "ultisnips is eager (kept eager per user decision)" +"lua $(loaded_lua ultisnips)"
# SMOKE_ROWS_END

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
