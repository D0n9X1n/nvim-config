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
  printf %s "local p=require('lazy.core.config').plugins['$name']; if p and p._.loaded then vim.cmd('cq') end"
}

assert_not_eager()       { nvim_probe "$1 not eager"            +"lua $(not_loaded_lua "$1")"; }
assert_loads_on_ft()     { nvim_probe "$1 loads on ft=$2"       +"e scratch.$2" +"lua $(loaded_lua "$1")"; }
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
# SMOKE_ROWS_END

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
