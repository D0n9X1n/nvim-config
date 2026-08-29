#!/usr/bin/env bash
# scripts/smoke.sh — lazy-loading smoke matrix
set -euo pipefail
cd "$(dirname "$0")/.."

REPO_DIR=$PWD
SMOKE_TMP=$(mktemp -d /tmp/nvim-smoke.XXXXXX)
trap 'rm -rf "$SMOKE_TMP"' EXIT
export TMPDIR="$SMOKE_TMP/tmp"
mkdir -p "$TMPDIR"
XDG_CONFIG_HOME="$SMOKE_TMP/config"
mkdir -p "$XDG_CONFIG_HOME"
ln -s "$REPO_DIR" "$XDG_CONFIG_HOME/nvim"

LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [ ! -d "$LAZY_DIR" ]; then
  printf 'lazy.nvim is not installed at %s; refusing to install during smoke tests\n' "$LAZY_DIR" >&2
  exit 1
fi

export NVIM_SMOKE_NO_INSTALL="$SMOKE_TMP/no-install.lua"
cat > "$NVIM_SMOKE_NO_INSTALL" <<'LUA'
local lazy_path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
vim.opt.runtimepath:prepend(lazy_path)

local lazy = require('lazy')
local setup = lazy.setup
lazy.setup = function(spec, options)
  options = options or {}
  options.install = options.install or {}
  options.install.missing = false
  return setup(spec, options)
end
LUA

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

# Run nvim headless with a Lua predicate. Predicate must call
# vim.cmd('cq') to fail. Returns 0 on pass, non-zero on fail.
nvim_probe() {
  local desc="$1"; shift
  local output
  if output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME" nvim --headless --cmd "lua dofile(vim.env.NVIM_SMOKE_NO_INSTALL)" "$@" +qa 2>&1); then
    ok "$desc"
  else
    bad "$desc"
    printf '%s\n' "$output" >&2
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

export NVIM_SMOKE_BUFFERLINE_CONFIG="$SMOKE_TMP/bufferline-config.lua"
cat > "$NVIM_SMOKE_BUFFERLINE_CONFIG" <<'LUA'
local function run()
  local options = require('bufferline.config').options
  local formatter = assert(options.name_formatter, 'Bufferline name_formatter is missing')

  local file_name = formatter({ path = '/tmp/project/example.lua', name = 'fallback.lua' })
  assert(file_name == 'example.lua', 'name_formatter must derive the basename from buf.path')

  local supplied_name = 'project/'
  local directory_name = formatter({ path = '/tmp/project/', name = supplied_name })
  assert(directory_name == supplied_name, 'name_formatter must fall back when a trailing slash has no basename')

  assert(options.indicator.style == 'icon', 'Bufferline indicator must use icon style')
  assert(options.indicator.icon == ' ', 'Bufferline indicator must reserve one invisible column')
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cq')
end
LUA

export NVIM_SMOKE_DIRECTORY="$SMOKE_TMP/directory-regression.lua"
cat > "$NVIM_SMOKE_DIRECTORY" <<'LUA'
local function run()
  local repo = assert(vim.env.NVIM_SMOKE_REPO, 'NVIM_SMOKE_REPO is missing')
  local case = assert(vim.g.smoke_case, 'smoke case is missing')
  local uv = vim.uv or vim.loop

  local function normalize(path)
    if path == '' then
      return ''
    end
    return vim.fs.normalize(path):gsub('/+$', '')
  end

  repo = normalize(repo)

  local function tree_windows()
    local result = {}
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if vim.bo[bufnr].filetype == 'neo-tree' then
        result[#result + 1] = winid
      end
    end
    return result
  end

  local function listed_buffers()
    local result = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
        result[#result + 1] = bufnr
      end
    end
    return result
  end

  local function listed_paths_match(expected_paths)
    local expected = {}
    for _, path in ipairs(expected_paths) do
      expected[normalize(path)] = true
    end

    local buffers = listed_buffers()
    if #buffers ~= #expected_paths then
      return false
    end
    for _, bufnr in ipairs(buffers) do
      if not expected[normalize(vim.api.nvim_buf_get_name(bufnr))] then
        return false
      end
    end
    return true
  end

  local function listed_buffer_summary()
    local result = {}
    for _, bufnr in ipairs(listed_buffers()) do
      result[#result + 1] = {
        bufnr = bufnr,
        filetype = vim.bo[bufnr].filetype,
        path = normalize(vim.api.nvim_buf_get_name(bufnr)),
      }
    end
    return vim.inspect(result)
  end

  local tree_win
  local state
  local settled = vim.wait(5000, function()
    local wins = tree_windows()
    if #wins ~= 1 then
      return false
    end

    local manager = require('neo-tree.sources.manager')
    local candidate = manager.get_state('filesystem')
    if candidate.winid ~= wins[1] or not candidate._ready or not candidate.tree then
      return false
    end

    tree_win = wins[1]
    state = candidate
    return true
  end, 10)

  assert(settled, 'directory startup did not settle to one ready Neo-tree window')
  assert(vim.api.nvim_win_get_width(tree_win) == 32, 'Neo-tree width must be 32 columns')
  assert(normalize(state.path or '') == repo, 'Neo-tree root must be the positional directory')

  local tree_buf = vim.api.nvim_win_get_buf(tree_win)
  assert(not vim.bo[tree_buf].buflisted, 'Neo-tree buffer must not be listed')
  for _, bufnr in ipairs(listed_buffers()) do
    assert(normalize(vim.api.nvim_buf_get_name(bufnr)) ~= repo, 'the directory buffer must not remain listed')
  end

  if case == 'startup' then
    return
  end

  local renderer = require('neo-tree.ui.renderer')
  local commands = require('neo-tree.sources.filesystem.commands')

  local file_paths = {}
  for _, node in ipairs(renderer.get_all_visible_nodes(state.tree)) do
    local path = normalize(node.path or node:get_id())
    local stat = uv.fs_stat(path)
    local name = vim.fs.basename(path)
    if node.type == 'file' and stat and stat.type == 'file' and name:sub(1, 1) ~= '.' then
      file_paths[#file_paths + 1] = path
    end
  end
  assert(#file_paths >= 2, 'Neo-tree must expose at least two real files for the regression probe')

  local first_path = file_paths[1]
  local second_path = file_paths[2]

  local function assert_tree_persisted()
    local wins = tree_windows()
    assert(#wins == 1 and wins[1] == tree_win, 'the original Neo-tree window must persist')
    assert(vim.api.nvim_win_is_valid(tree_win), 'the original Neo-tree window became invalid')
    assert(vim.api.nvim_win_get_buf(tree_win) == tree_buf, 'the original Neo-tree buffer was replaced')
    assert(vim.api.nvim_win_get_width(tree_win) == 32, 'Neo-tree width changed after opening a file')
  end

  local function open_from_tree(path)
    vim.api.nvim_set_current_win(tree_win)
    assert(renderer.focus_node(state, path), 'failed to focus file in Neo-tree: ' .. path)
    commands.open(state)
    assert(vim.wait(5000, function()
      return normalize(vim.api.nvim_buf_get_name(0)) == path
    end, 10), 'Neo-tree did not open file: ' .. path)
    assert_tree_persisted()
  end

  open_from_tree(first_path)
  assert(vim.wait(5000, function()
    return listed_paths_match({ first_path })
  end, 10), 'opening the first file must leave only that file listed; got ' .. listed_buffer_summary())

  if case == 'first_file' then
    return
  end

  local scratch_buf = vim.api.nvim_create_buf(true, true)
  open_from_tree(second_path)
  assert(vim.api.nvim_buf_is_valid(scratch_buf), 'later Neo-tree opens must preserve unrelated scratch buffers')
  vim.api.nvim_buf_delete(scratch_buf, { force = true })
  assert(vim.wait(5000, function()
    return listed_paths_match({ first_path, second_path })
  end, 10), 'opening the second file must leave exactly two real files listed')

  local left = vim.fn.maparg('<Left>', 'n', false, true)
  local right = vim.fn.maparg('<Right>', 'n', false, true)
  assert(left.rhs == ':BufferLineCyclePrev<CR>', 'effective <Left> mapping must invoke BufferLineCyclePrev')
  assert(right.rhs == ':BufferLineCycleNext<CR>', 'effective <Right> mapping must invoke BufferLineCycleNext')

  local bufferline = require('bufferline')
  local bufferline_state = require('bufferline.state')

  local function render()
    _G.nvim_bufferline()
  end

  local function component_ids()
    render()
    local elements = bufferline.get_elements().elements
    assert(#elements == 2, 'Bufferline must contain exactly the two real files')

    local ids = {}
    for _, element in ipairs(elements) do
      assert(element.id ~= tree_buf, 'Neo-tree must not be a Bufferline component')
      assert(vim.bo[element.id].filetype ~= 'neo-tree', 'Neo-tree must not be a Bufferline component')
      local path = normalize(element.path or '')
      assert(path == first_path or path == second_path, 'Bufferline contains a startup artifact')
      ids[#ids + 1] = element.id
    end
    return ids
  end

  local ids = component_ids()

  local function layout_snapshot()
    render()
    local column = bufferline_state.left_offset_size
    local snapshot = {}
    for _, component in ipairs(bufferline_state.components) do
      snapshot[#snapshot + 1] = {
        id = component.id,
        length = component.length,
        column = column,
      }
      column = column + component.length
    end
    return snapshot
  end

  vim.api.nvim_set_current_buf(ids[1])
  local baseline = layout_snapshot()

  local function press(lhs, expected_id)
    vim.api.nvim_feedkeys(vim.keycode(lhs), 'xt', false)
    assert(vim.wait(1000, function()
      return vim.api.nvim_get_current_buf() == expected_id
    end, 10), lhs .. ' did not select the expected Bufferline component')
    assert(listed_paths_match({ first_path, second_path }), lhs .. ' changed the listed file buffers')
    assert_tree_persisted()
    assert(vim.deep_equal(layout_snapshot(), baseline), lhs .. ' changed Bufferline IDs, order, lengths, or columns')
  end

  press('<Right>', ids[2])
  press('<Right>', ids[1])
  press('<Left>', ids[2])
  press('<Left>', ids[1])
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cq')
end
LUA

export NVIM_SMOKE_REPO="$REPO_DIR"

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
for p in nerdcommenter vim-repeat rainbow quick-scope vim-visual-multi todo-comments.nvim; do
  assert_not_eager "$p"
done
nvim_probe "nerdcommenter loads on BufReadPost"     +"e README.md" +"lua $(loaded_lua nerdcommenter)"
nvim_probe "vim-repeat loads on BufReadPost"        +"e README.md" +"lua $(loaded_lua vim-repeat)"
nvim_probe "rainbow loads on BufReadPost"           +"e README.md" +"lua $(loaded_lua rainbow)"
nvim_probe "quick-scope loads on BufReadPost"       +"e README.md" +"lua $(loaded_lua quick-scope)"
nvim_probe "vim-visual-multi loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-visual-multi)"
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
nvim_probe "neo-tree.nvim is eager (directory hijack ready at startup)" +"lua $(loaded_lua neo-tree.nvim)"
nvim_probe "Bufferline formatter and indicator keep stable width" +"lua dofile(vim.env.NVIM_SMOKE_BUFFERLINE_CONFIG)"
nvim_probe "nvim <directory> settles to one persistent Neo-tree" "$REPO_DIR" +"let g:smoke_case='startup'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
nvim_probe "opening first Neo-tree file preserves tree and listed buffers" "$REPO_DIR" +"let g:smoke_case='first_file'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
nvim_probe "Bufferline arrows cycle real files with stable layout" "$REPO_DIR" +"let g:smoke_case='bufferline'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
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
assert_not_eager gruvbox
nvim_probe "Apollo is eager (loaded at startup)" +"lua $(loaded_lua nvim-apollo-theme)"
nvim_probe "Apollo has priority = 1000" +"lua local p=require('lazy.core.config').plugins['nvim-apollo-theme']; if not (p and p.priority == 1000) then vim.cmd('cq') end"
nvim_probe "Apollo is the active colorscheme" +"lua if vim.g.colors_name ~= 'apollo' then vim.cmd('cq') end"

echo
echo "== Intentionally eager (kept eager per user decision) =="
nvim_probe "lualine.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua lualine.nvim)"
nvim_probe "bufferline.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua bufferline.nvim)"
nvim_probe "ultisnips is eager (kept eager per user decision)" +"lua $(loaded_lua ultisnips)"
# SMOKE_ROWS_END

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
