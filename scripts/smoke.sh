#!/usr/bin/env bash
# scripts/smoke.sh — lazy-loading smoke matrix
set -euo pipefail
cd "$(dirname "$0")/.."

REPO_DIR=$PWD
SMOKE_TMP=$(mktemp -d /tmp/nvim-smoke.XXXXXX)
trap 'rm -rf "$SMOKE_TMP"' EXIT
export NVIM_SMOKE_LAZY_SOURCE="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
if [ ! -d "$NVIM_SMOKE_LAZY_SOURCE/lazy.nvim" ]; then
  printf 'lazy.nvim is not installed at %s; refusing to install during smoke tests\n' "$NVIM_SMOKE_LAZY_SOURCE" >&2
  exit 1
fi
export TMPDIR="$SMOKE_TMP/tmp"
export XDG_CONFIG_HOME="$SMOKE_TMP/config"
export XDG_DATA_HOME="$SMOKE_TMP/data"
export XDG_STATE_HOME="$SMOKE_TMP/state"
export XDG_CACHE_HOME="$SMOKE_TMP/cache"
export NVIM_SMOKE_REPO="$REPO_DIR"
export NVIM_SMOKE_PUBLIC_CONFIG="$XDG_CONFIG_HOME/nvim"
mkdir -p "$TMPDIR" "$XDG_CONFIG_HOME/nvim" "$XDG_DATA_HOME/nvim/lazy" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
python3 - <<'PY'
import os
import pathlib
import shutil
import subprocess

repo = pathlib.Path(os.environ['NVIM_SMOKE_REPO'])
config = pathlib.Path(os.environ['NVIM_SMOKE_PUBLIC_CONFIG'])
for name in subprocess.check_output(['git', 'ls-files', '-z', 'init.lua', 'lua', 'UltiSnips'], text=True).split('\0'):
    if not name or pathlib.Path(name).name in ('private.lua', 'private_config.lua'):
        continue
    target = config / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / name, target)
if os.environ.get('NVIM_SMOKE_BUFFERLINE_SOURCE'):
    import json
    spec = config / 'lua/plugins/init.lua'
    spec.write_text(spec.read_text().replace("'MOSconfig/bufferline.nvim',", "'MOSconfig/bufferline.nvim', dir = " + json.dumps(os.environ['NVIM_SMOKE_BUFFERLINE_SOURCE']) + ','))
plugins = pathlib.Path(os.environ['XDG_DATA_HOME']) / 'nvim/lazy'
for source in pathlib.Path(os.environ['NVIM_SMOKE_LAZY_SOURCE']).iterdir():
    if source.is_dir():
        (plugins / source.name).symlink_to(source, target_is_directory=True)
PY

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
  options.checker = { enabled = false }
  options.change_detection = { enabled = false }
  options.lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json'
  options.root = vim.env.NVIM_SMOKE_LAZY_SOURCE
  options.pkg = { enabled = false }
  return setup(spec, options)
end
LUA

PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

nvim_probe() {
  local desc="$1"; shift
  local output
  if output=$(python3 "$REPO_DIR/scripts/smoke-probe.py" "$@" 2>&1); then
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
assert_loads_on_ft()     { nvim_probe "$1 loads on ft=$2"       +"e scratch.$2" +"lua $(loaded_lua "$1")"; }
assert_loads_on_ft_explicit() { nvim_probe "$1 loads on ft=$2" +"e scratch" +"set filetype=$2" +"lua $(loaded_lua "$1")"; }
assert_loads_on_cmd()    { nvim_probe "$1 loads on :$2"         +"$2"   +"lua $(loaded_lua "$1")"; }
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
  assert(vim.tbl_isempty(options.offsets or {}), 'Bufferline header must not reserve repeated Explorer space')
  assert(options.tab_size == 16 and options.enforce_regular_tabs, 'Buffer tabs must retain configurable width 16')
  assert(options.truncate_names, 'Long buffer titles must be truncated')
  assert(not options.show_buffer_close_icons, 'Buffer tabs must not show close buttons')
  assert(options.separator_style == 'slope', 'Buffer tabs must use the local sloped default')
  local function selected_colors()
    local selected = vim.api.nvim_get_hl(0, { name = 'BufferLineBufferSelected', link = false })
    local background = vim.api.nvim_get_hl(0, { name = 'BufferLineBackground', link = false })
    assert(selected.bg == 0x365b80 and selected.fg == 0xffffff and selected.bold, 'Active tab must have a contrasting background')
    assert(selected.bg ~= background.bg, 'Active and inactive tabs must be distinguishable')
    local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg
    for _, name in ipairs({ 'BufferLineFill', 'BufferLineBackground', 'BufferLineBufferVisible' }) do
      assert(vim.api.nvim_get_hl(0, { name = name, link = false }).bg == normal, 'Inactive header areas must match the editor background')
    end
  end
  selected_colors()
  vim.cmd.colorscheme('apollo')
  selected_colors()
  local closed = vim.api.nvim_create_buf(true, false)
  options.close_command(closed)
  assert(vim.fn.buflisted(closed) == 0, 'Close action must delete the requested clean buffer')
  local dirty = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(dirty, 0, -1, false, { 'unsaved text' })
  local notify, warning = vim.notify, nil
  vim.notify = function(message) warning = message end
  options.close_command(dirty)
  vim.notify = notify
  assert(warning and vim.api.nvim_buf_is_valid(dirty), 'Close action must refuse unsaved changes')
  assert(vim.api.nvim_buf_get_lines(dirty, 0, 1, false)[1] == 'unsaved text', 'Close action must preserve dirty text')
  vim.bo[dirty].modified = false
  options.close_command(dirty)

  local api = vim.api
  local editor, original = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local opened = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(opened, '/tmp/smoke-opened-buffer.txt')
  api.nvim_win_set_buf(editor, opened)
  vim.cmd('vsplit')
  local second = api.nvim_get_current_win()
  vim.cmd('tab split')
  local other_tab = api.nvim_get_current_win()
  local windows = api.nvim_list_wins()
  options.close_command(opened)
  assert(vim.fn.buflisted(opened) == 0, 'Close action must remove an open buffer')
  local replacement = api.nvim_win_get_buf(editor)
  for _, win in ipairs({ editor, second, other_tab }) do
    assert(api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == replacement, 'Close action must preserve every split across tabs')
  end
  assert(#windows == #api.nvim_list_wins(), 'Close action must not remove windows')
  local locked = api.nvim_create_buf(true, false)
  api.nvim_win_set_buf(second, locked)
  vim.wo[second].winfixbuf = true
  local old_notify, refused = vim.notify, false
  vim.notify = function() refused = true end
  options.close_command(locked)
  vim.notify = old_notify
  assert(refused and api.nvim_win_get_buf(second) == locked and vim.fn.buflisted(locked) == 1, 'Locked views must be refused before modifying any window')
  vim.wo[second].winfixbuf = false
  options.close_command(locked)
  local hidden = api.nvim_create_buf(true, false)
  options.close_command(hidden)
  assert(api.nvim_win_get_buf(editor) == replacement, 'Closing hidden buffers must not switch the editor')
  vim.cmd('tabclose')
  api.nvim_set_current_win(editor)
  api.nvim_win_close(second, false)
  api.nvim_win_set_buf(editor, original)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cq')
end
LUA

export NVIM_SMOKE_SEARCH="$SMOKE_TMP/search-regression.lua"
cat > "$NVIM_SMOKE_SEARCH" <<'LUA'
local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-i', 'NONE', '-n',
  '--cmd', 'lua dofile(vim.env.NVIM_SMOKE_NO_INSTALL)' }, {
  rpc = true,
  env = { NVIM_RPLUGIN_MANIFEST = vim.env.NVIM_SMOKE_LAZY_SOURCE .. '/../rplugin.vim' },
})
local function lua(code) return vim.fn.rpcrequest(child, 'nvim_exec_lua', code, {}) end
local function input(keys)
  vim.fn.rpcrequest(child, 'nvim_input', keys)
end
local ok, err = xpcall(function()
  assert(child > 0)
  lua("assert(not require('lazy.core.config').plugins['ag.vim']._.loaded)")
  for attempt = 1, 2 do
    input(',s')
    assert(vim.wait(3000, function() return lua("return vim.fn.getcmdline() == 'Ag '") end, 20), 'Search input missing')
    lua("assert(vim.api.nvim_get_commands({}).Ag.complete == 'file'); vim.wait(600)")
    local messages = lua("return vim.api.nvim_exec2('messages', { output = true }).output")
    assert(not messages:find('E704', 1, true) and not messages:find('E714', 1, true), messages)
    input('search-regression-query')
    assert(vim.wait(3000, function() return lua("return vim.fn.getcmdline() == 'Ag search-regression-query'") end, 20), 'Search input is not editable')
    input('<Esc>')
    assert(vim.wait(1000, function() return lua("return vim.api.nvim_get_mode().mode == 'n'") end, 20))
  end
  input(',sfast-query')
  assert(vim.wait(3000, function() return lua("return vim.fn.getcmdline() == 'Ag fast-query'") end, 20), 'Fast query must follow the command prefix')
  input('<Esc>')
  lua("assert(not vim.bo.modified)")
  lua([=[
    local api = vim.api
    local runtime = require('bufferline.multiline.runtime')
    local editor, original = api.nvim_get_current_win(), api.nvim_get_current_buf()
    api.nvim_buf_set_name(original, vim.env.TMPDIR .. '/search-editor.txt')
    runtime.flush('test')
    local header = runtime.handles()[api.nvim_get_current_tabpage()].win
    vim.fn.setqflist({ { bufnr = original, lnum = 1, text = 'search result' } })
    vim.cmd('botright copen')
    local results = api.nvim_get_current_buf()
    assert(vim.bo[results].buftype == 'quickfix' and not vim.bo[results].buflisted)
    assert(vim.tbl_contains(require('lualine').get_config().options.ignore_focus, 'qf'), 'Results must not replace editor statusline context')
    runtime.flush('test')
    local h = runtime.handles()[api.nvim_get_current_tabpage()]
    assert(h.editor == editor and h.win == header, 'Results must not become the header editor')
    for _, component in ipairs(h.frame.visible_components) do assert(component.id ~= results) end
    vim.cmd('cclose')
    runtime.flush('test')
    assert(api.nvim_win_is_valid(editor) and api.nvim_win_get_buf(editor) == original)
    assert(runtime.owns(header) and vim.o.showtabline == 2 and vim.o.tabline:find('SystemBarHost', 1, true))
  ]=])
end, debug.traceback)
if child > 0 then vim.fn.jobstop(child) end
assert(ok, err)
LUA

export NVIM_SMOKE_EMPTY_BUFFER="$SMOKE_TMP/empty-buffer-regression.lua"
cat > "$NVIM_SMOKE_EMPTY_BUFFER" <<'LUA'
local api = vim.api
local function blank(lines, modified)
  local buf = api.nvim_create_buf(true, false)
  if lines then api.nvim_buf_set_lines(buf, 0, -1, false, lines) end
  if modified ~= nil then vim.bo[buf].modified = modified end
  return buf
end
local function open_file()
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.txt')
  api.nvim_set_current_buf(buf)
  vim.wait(80)
  return buf
end
local empty = blank()
local dirty = blank({ 'unsaved' })
local content = blank({ 'keep even when marked clean' }, false)
local whitespace = blank({ ' ' }, false)
local scratch = api.nvim_create_buf(false, true)
local displayed = blank()
api.nvim_set_current_buf(displayed)
vim.cmd('vsplit')
local file = open_file()
assert(vim.fn.buflisted(empty) == 0, 'Opening a file must remove hidden empty unnamed buffers')
for _, buf in ipairs({ dirty, content, whitespace, displayed, scratch }) do
  assert(api.nvim_buf_is_valid(buf), 'Must preserve text, displayed buffers and scratch buffers')
end
assert(vim.bo[dirty].modified and api.nvim_buf_get_lines(dirty, 0, 1, false)[1] == 'unsaved')
assert(api.nvim_get_current_buf() == file, 'Cleanup must not change focus')
local again = blank()
open_file()
assert(vim.fn.buflisted(again) == 0, 'Cleanup must work beyond first startup')
local raced = blank()
api.nvim_exec_autocmds('BufEnter', { buffer = api.nvim_get_current_buf() })
api.nvim_buf_set_lines(raced, 0, -1, false, { 'typed before cleanup' })
vim.wait(80)
assert(api.nvim_buf_is_valid(raced) and vim.bo[raced].modified, 'Deferred cleanup must recheck modifications')
LUA

export NVIM_SMOKE_HEADER="$SMOKE_TMP/header-regression.lua"
cat > "$NVIM_SMOKE_HEADER" <<'LUA'
local api = vim.api
local runtime = require('bufferline.multiline.runtime')
vim.o.columns = 100
vim.o.lines = 40
local editor, original = api.nvim_get_current_win(), api.nvim_get_current_buf()
for index = 1, 40 do
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, string.format('%s/header-file-%02d.txt', vim.env.TMPDIR, index))
end
runtime.flush('test')
local handle = assert(runtime.handles()[api.nvim_get_current_tabpage()])
assert(handle.frame.total_rows > 3, 'header fixture must overflow')
assert(vim.o.laststatus == 3, 'Use one bottom statusline, not a scratch-header banner')
assert(vim.tbl_contains(require('lualine').get_config().options.ignore_focus, 'bufferline'), 'Statusline must retain editor context while navigating the header')
local title_lines = api.nvim_buf_get_lines(handle.buf, 0, -1, false)
assert(table.concat(title_lines):find('…', 1, true), 'Long titles must visibly truncate with an ellipsis')
for _, line in ipairs(title_lines) do
  assert(vim.fn.strdisplaywidth(line) <= api.nvim_win_get_width(handle.win), 'Header text must fit its editor width')
end
local function keys(value)
  api.nvim_feedkeys(api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
  vim.wait(30)
end
for _, split in ipairs({ 'split', 'vsplit' }) do
  for _, close_original in ipairs({ false, true }) do
    local first_editor = api.nvim_get_current_win()
    vim.cmd(split)
    local second_editor = api.nvim_get_current_win()
    vim.wait(30)
    local closing = close_original and first_editor or second_editor
    local surviving = close_original and second_editor or first_editor
    api.nvim_set_current_win(closing)
    keys(':q<CR>')
    assert(not api.nvim_win_is_valid(closing) and api.nvim_win_is_valid(surviving), 'Quit must close only the requested split')
    assert(require('bufferline.config').options.multiline.enabled and vim.o.tabline:find('SystemBarHost', 1, true), 'Split quit must retain multiline tabs and the native banner')
    handle = assert(runtime.handles()[api.nvim_get_current_tabpage()])
    assert(runtime.owns(handle.win), 'Split quit must retain or rebuild an owned header')
    editor = surviving
    api.nvim_set_current_win(editor)
  end
end
local editor_cursor = vim.o.guicursor
keys('<C-k>')
assert(api.nvim_get_current_win() == handle.win, 'Ctrl-k must enter the header')
assert(vim.o.guicursor:find('BufferlineHiddenCursor', 1, true), 'Header must hide the normal-mode cursor')
assert(vim.api.nvim_get_hl(0, { name = 'BufferlineHiddenCursor', link = false }).blend == 100, 'Header cursor must be fully transparent')
local cursor = api.nvim_win_get_cursor(handle.win)
keys('l')
assert(not vim.deep_equal(cursor, api.nvim_win_get_cursor(handle.win)), 'header l must move to another entry')
keys('h')
assert(vim.deep_equal(cursor, api.nvim_win_get_cursor(handle.win)), 'header h must return to the previous entry')
local first = handle.first_row
keys('jjjj')
assert(handle.first_row > first, 'header j must reveal overflow rows')
keys('kkkk')
assert(handle.first_row == first, 'header k must return to the first rows')
assert(api.nvim_win_get_buf(editor) == original, 'header navigation must not switch the editing buffer')
keys('<Esc>')
assert(api.nvim_get_current_win() == editor, 'Escape must return to the editing window')
assert(vim.o.guicursor == editor_cursor, 'Leaving header must restore the original cursor')
assert(api.nvim_win_get_buf(editor) == original, 'Escape must not activate a candidate')
keys('<C-k>l<CR>')
assert(api.nvim_get_current_win() == editor, 'Enter must restore editing focus')
assert(api.nvim_win_get_buf(editor) ~= original, 'Enter must activate the candidate')
local active = api.nvim_win_get_buf(editor)
keys('<C-k>l')
local candidate = handle.candidate
assert(candidate ~= active, 'Close fixture must select a hidden buffer')
keys('x')
assert(vim.fn.buflisted(candidate) == 0, 'Header x must remove the candidate')
assert(api.nvim_win_get_buf(editor) == active, 'Hidden-buffer x must not switch the editor')
assert(api.nvim_get_current_win() == handle.win, 'Header x must retain header focus')
candidate = handle.candidate
api.nvim_buf_set_lines(candidate, 0, -1, false, { 'unsaved candidate' })
local notify, warned = vim.notify, false
vim.notify = function() warned = true end
keys('x')
vim.notify = notify
assert(warned and handle.candidate == candidate and vim.bo[candidate].modified, 'Refused x must retain dirty candidate')
vim.bo[candidate].modified = false
keys('<Esc><C-k>x')
assert(vim.fn.buflisted(active) == 0, 'Header x must close the active file')
assert(api.nvim_get_current_win() == handle.win and runtime.active(), 'Active close must retain usable header')
keys('<Esc>')
for _, hidden in ipairs({ false, true }) do
  local editing = api.nvim_get_current_buf()
  if not hidden then vim.cmd('vsplit') end
  local terminal_win = api.nvim_get_current_win()
  local terminal = api.nvim_create_buf(true, false)
  api.nvim_set_current_buf(terminal)
  local job = vim.fn.jobstart({ vim.v.progpath, '-u', 'NONE', '-i', 'NONE', '-n' }, { term = true })
  assert(job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1, 'Header fixture must have a live terminal')
  local pid = vim.fn.jobpid(job)
  local ok, err = xpcall(function()
    keys('<C-\\><C-n>')
    if hidden then api.nvim_set_current_buf(editing) end
    api.nvim_set_current_win(editor)
    runtime.flush('test')
    keys('<C-k>')
    handle = assert(runtime.handles()[api.nvim_get_current_tabpage()])
    for _ = 1, #handle.frame.positions do
      if handle.candidate == terminal then break end
      keys('l')
    end
    assert(handle.candidate == terminal, 'Header keys must select the terminal: ' .. vim.inspect({
      hidden = hidden, candidate = handle.candidate, terminal = terminal,
      current = api.nvim_get_current_win(), header = handle.win, mode = api.nvim_get_mode().mode,
    }))
    local windows = api.nvim_list_wins()
    keys('x')
    assert(vim.fn.buflisted(terminal) == 0, 'Header x must remove a running terminal')
    assert(vim.wait(3000, function()
      return vim.fn.jobwait({ job }, 0)[1] ~= -1 and not vim.uv.kill(pid, 0)
    end, 10), 'Header x must stop the terminal process')
    assert(vim.deep_equal(api.nvim_list_wins(), windows), 'Terminal x must preserve splits')
    assert(api.nvim_get_current_win() == handle.win and runtime.active(), 'Terminal x must retain header focus')
    assert(handle.candidate ~= terminal and vim.fn.buflisted(handle.candidate) == 1, 'Terminal x must select a surviving neighbor')
    assert(api.nvim_win_get_buf(editor) == editing, 'Terminal x must preserve the other editing buffer')
    keys('<Esc>')
    if not hidden then api.nvim_win_close(terminal_win, false) end
  end, debug.traceback)
  if vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
  assert(ok, err)
end
api.nvim_buf_set_lines(0, 0, -1, false, { 'first line', 'second line', 'third line' })
api.nvim_win_set_cursor(editor, { 1, 0 })
keys('jl')
assert(vim.deep_equal(api.nvim_win_get_cursor(editor), { 2, 1 }), 'ordinary editor j/l mappings must still work')
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
    assert(vim.wait(1000, function()
      return vim.bo.buftype == '' and vim.bo.filetype ~= 'neo-tree'
        and vim.api.nvim_win_get_config(0).relative == ''
    end, 10), 'directory startup must focus the editor, not Neo-tree or the buffer header')
    local editor = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(tree_win)
    vim.wait(100)
    assert(vim.api.nvim_get_current_win() == tree_win, 'explicit tree focus must not be stolen later')
    vim.api.nvim_set_current_win(editor)
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

  if case == 'terminal' then
    local api = vim.api
    local editor, file = api.nvim_get_current_win(), api.nvim_get_current_buf()
    api.nvim_buf_set_lines(file, 0, -1, false, { 'keep unsaved file text' })
    local runtime = require('bufferline.multiline.runtime')
    for _, source in ipairs({ 'editor', 'tree', 'header' }) do
      runtime.flush('terminal-test')
      local header = runtime.handles()[api.nvim_get_current_tabpage()].win
      local windows = api.nvim_tabpage_list_wins(0)
      api.nvim_set_current_win(source == 'tree' and tree_win or source == 'header' and header or editor)
      local terminal, terminal_win, job
      local ok, err = xpcall(function()
        api.nvim_feedkeys(',t', 'xt', false)
        terminal, terminal_win, job = api.nvim_get_current_buf(), api.nvim_get_current_win(), vim.b.terminal_job_id
        assert(terminal_win ~= editor and vim.bo.buftype == 'terminal', 'terminal must split the main editor from ' .. source)
        assert(api.nvim_win_get_buf(editor) == file, 'file must remain visible in its original window')
        assert(job and vim.fn.jobwait({ job }, 0)[1] == -1, 'terminal shell must be running')
        local pid = vim.fn.jobpid(job)
        runtime.flush('terminal-test')
        local remaining = vim.tbl_filter(function(win) return win ~= terminal_win end, api.nvim_tabpage_list_wins(0))
        assert(vim.deep_equal(remaining, windows), 'terminal must add exactly one split and preserve existing windows')
        local editor_pos, terminal_pos = api.nvim_win_get_position(editor), api.nvim_win_get_position(terminal_win)
        assert(terminal_pos[1] > editor_pos[1] and terminal_pos[2] == editor_pos[2], 'terminal must split below the editor, not the tree or header')
        assert(api.nvim_win_get_width(terminal_win) == api.nvim_win_get_width(editor), 'terminal must stay within the editor width')
        assert_tree_persisted()
        assert(runtime.owns(header) and api.nvim_win_get_position(header)[1] == 1, 'terminal must stay below banner and header')
        local header_height, cmdheight = api.nvim_win_get_height(header), vim.o.cmdheight
        local function chord(key)
          api.nvim_feedkeys(vim.keycode('<C-w>' .. key), 'xt', false)
          vim.wait(30)
          runtime.flush('WinResized')
        end
        local height = api.nvim_win_get_height(terminal_win)
        chord('K')
        assert(api.nvim_win_get_height(terminal_win) == height + 1, 'Ctrl-w K must expand bottom terminal up by one row')
        chord('J')
        assert(api.nvim_win_get_height(terminal_win) == height, 'Ctrl-w J must restore terminal height')
        for _, key in ipairs({ '<', '>', '-', '=' }) do
          chord(key)
          local current_pos, file_pos = api.nvim_win_get_position(terminal_win), api.nvim_win_get_position(editor)
          if key == '<' then assert(current_pos[2] < file_pos[2], 'terminal moves left of file')
          elseif key == '>' then assert(current_pos[2] > file_pos[2], 'terminal moves right of file')
          elseif key == '-' then assert(current_pos[1] < file_pos[1], 'terminal moves above file')
          else assert(current_pos[1] > file_pos[1], 'terminal moves below file') end
          if key == '<' or key == '>' then
            local width = api.nvim_win_get_width(terminal_win)
            chord('H')
            assert(api.nvim_win_get_width(terminal_win) == width + (key == '<' and -1 or 1), 'Ctrl-w H must move divider left one column')
            chord('L')
            assert(api.nvim_win_get_width(terminal_win) == width, 'Ctrl-w L must restore divider')
          end
          assert(api.nvim_get_current_win() == terminal_win, 'window controls must preserve terminal focus')
          assert(api.nvim_win_get_buf(terminal_win) == terminal and api.nvim_win_get_buf(editor) == file, 'movement must preserve both buffers')
          assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'window controls must keep shell running')
          assert(api.nvim_win_get_height(header) == header_height and api.nvim_win_get_position(header)[1] == 1, 'window controls must preserve header')
          assert(api.nvim_win_get_position(header)[2] == api.nvim_win_get_width(tree_win) + 1, 'header must start after the sidebar')
          assert(api.nvim_win_get_width(header) == vim.o.columns - api.nvim_win_get_width(tree_win) - 1, 'header must span every editor and terminal after redraw')
          assert(vim.o.cmdheight == cmdheight, 'window controls must not resize the command line')
          assert_tree_persisted()
        end
        local handle = runtime.handles()[api.nvim_get_current_tabpage()]
        local entry
        for _, component in ipairs(handle.frame.visible_components) do
          if component.id == terminal then entry = component end
        end
        assert(entry and entry.name == 'Terminal' and vim.bo[terminal].buflisted, 'terminal must have a listed Terminal entry')
        assert(table.concat(api.nvim_buf_get_lines(handle.buf, 0, -1, false)):find('Terminal', 1, true), 'Terminal label must be rendered in the header')
        api.nvim_set_current_win(header)
        for _ = 1, #handle.frame.positions do
          if handle.candidate == terminal then break end
          api.nvim_feedkeys('l', 'xt', false)
        end
        assert(handle.candidate == terminal, 'header navigation must select the Terminal entry')
        api.nvim_feedkeys('x', 'xt', false)
        assert(vim.wait(1000, function() return vim.fn.buflisted(terminal) == 0 end, 10), 'header x must remove the Terminal buffer')
        assert(vim.wait(3000, function()
          return vim.fn.jobwait({ job }, 0)[1] ~= -1 and not vim.uv.kill(pid, 0)
        end, 10), 'header x must stop the terminal shell')
        assert(api.nvim_win_get_buf(editor) == file and vim.bo[file].modified, 'closing terminal must preserve unsaved file')
        assert(api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'keep unsaved file text', 'file text must be preserved')
        assert_tree_persisted()
      end, debug.traceback)
      if job and vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
      if terminal and api.nvim_buf_is_valid(terminal) and vim.bo[terminal].buftype == 'terminal' then api.nvim_buf_delete(terminal, { force = true }) end
      if terminal_win and terminal_win ~= editor and api.nvim_win_is_valid(terminal_win) then api.nvim_win_close(terminal_win, false) end
      api.nvim_set_current_win(editor)
      assert(ok, err)
    end
    return
  end

  if case == 'close_last' then
    local original = vim.api.nvim_get_current_buf()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    vim.api.nvim_feedkeys(',q', 'xt', false)
    assert(vim.fn.buflisted(original) == 0, 'closing the last file must unlist it')
    assert(vim.api.nvim_buf_get_name(0) == '', 'closing the last file must leave an unnamed buffer')
    assert(#listed_buffers() == 1, 'closing the last file must leave one listed buffer')
    assert(vim.deep_equal(vim.api.nvim_tabpage_list_wins(0), windows), 'closing a file must preserve windows')
    assert_tree_persisted()
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
    local runtime = package.loaded['bufferline.multiline.runtime']
    if runtime and runtime.active() then
      runtime.flush('test')
    else
      _G.nvim_bufferline()
    end
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

export NVIM_SMOKE_DIRECTORY_QUIT="$SMOKE_TMP/directory-quit.lua"
cat > "$NVIM_SMOKE_DIRECTORY_QUIT" <<'LUA'
for _, dirty in ipairs({ false, true }) do
  local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-i', 'NONE', '-n',
    '--cmd', 'lua dofile(vim.env.NVIM_SMOKE_NO_INSTALL)', vim.env.NVIM_SMOKE_REPO }, { rpc = true })
  local function lua(code) return vim.fn.rpcrequest(child, 'nvim_exec_lua', code, {}) end
  local ok, err = xpcall(function()
    assert(child > 0, 'directory quit probe must start')
    assert(vim.wait(5000, function()
      return lua([=[
        local state = require('neo-tree.sources.manager').get_state('filesystem')
        return state._ready and state.tree ~= nil and vim.bo.buftype == '' and vim.bo.modifiable
          and vim.bo.filetype ~= 'neo-tree' and vim.bo.filetype ~= 'bufferline'
          and vim.fn.isdirectory(vim.api.nvim_buf_get_name(0)) == 0
          and vim.api.nvim_win_get_config(0).relative == ''
      ]=]) == true
    end, 20), 'directory startup must settle with editor focus')
    if dirty then lua("vim.g.quit_test_buf = vim.api.nvim_get_current_buf(); vim.api.nvim_buf_set_lines(vim.g.quit_test_buf, 0, -1, false, { 'keep unsaved work' })") end
    vim.fn.rpcrequest(child, 'nvim_input', ':q<CR>')
    if dirty then
      assert(vim.wait(1000, function()
        return lua("return vim.api.nvim_exec2('messages', { output = true }).output:find('E37', 1, true) ~= nil") == true
      end, 20), 'quit must refuse unsaved startup edits')
      assert(vim.fn.jobwait({ child }, 0)[1] == -1, 'dirty editor must remain running')
      assert(lua("return vim.bo[vim.g.quit_test_buf].modified and vim.api.nvim_buf_get_lines(vim.g.quit_test_buf, 0, 1, false)[1] == 'keep unsaved work'") == true, 'quit must preserve dirty text')
    else
      assert(vim.fn.jobwait({ child }, 3000)[1] == 0, 'one :q must exit a clean directory session')
    end
  end, debug.traceback)
  if vim.fn.jobwait({ child }, 0)[1] == -1 then vim.fn.jobstop(child) end
  assert(ok, err)
end
LUA

export NVIM_SMOKE_UPRIGHT="$SMOKE_TMP/upright-highlights.lua"
cat > "$NVIM_SMOKE_UPRIGHT" <<'LUA'
local api = vim.api
local function upright()
  local namespaces = { 0 }
  for _, id in pairs(api.nvim_get_namespaces()) do namespaces[#namespaces + 1] = id end
  for _, id in ipairs(namespaces) do
    for _, hl in pairs(api.nvim_get_hl(id, { link = true })) do
      if hl.italic or (hl.cterm and hl.cterm.italic) then return false end
    end
  end
  return true
end
assert(vim.wait(1000, upright, 10), 'startup highlights must not contain italics')
local namespace = api.nvim_create_namespace('upright-regression')
local style = { fg = 0x123456, bg = 0x654321, sp = 0xaabbcc, italic = true, bold = true,
  underline = true, default = true, ctermfg = 12, ctermbg = 3, cterm = { italic = true, bold = true, underline = true } }
local expected = vim.deepcopy(style)
expected.default = nil
expected.italic = nil
expected.cterm.italic = nil
for _, id in ipairs({ 0, namespace }) do
  api.nvim_set_hl(id, 'UprightTest', style)
  api.nvim_set_hl(id, 'UprightLink', { link = 'UprightTest' })
end
api.nvim_exec_autocmds('User', { pattern = 'LazyLoad' })
assert(vim.wait(1000, upright, 10), 'lazy plugin highlights must not restore italics')
for _, id in ipairs({ 0, namespace }) do
  assert(vim.deep_equal(api.nvim_get_hl(id, { name = 'UprightTest', link = true }), expected), 'non-italic attributes must remain unchanged')
  assert(api.nvim_get_hl(id, { name = 'UprightLink', link = true }).link == 'UprightTest', 'highlight links must remain links')
end
for _, background in ipairs({ 'light', 'dark' }) do
  vim.o.background = background
  vim.cmd('colorscheme apollo')
  assert(vim.wait(1000, upright, 10), 'theme changes must not restore italics')
end
for _, event in ipairs({ 'FileType', 'Syntax' }) do
  api.nvim_set_hl(0, 'UprightLate', { italic = true, cterm = { italic = true } })
  if event == 'FileType' then vim.bo.filetype = 'lua' else vim.bo.syntax = 'lua' end
  assert(vim.wait(1000, upright, 10), event .. ' must not restore italics')
end
print('UPRIGHT_HIGHLIGHTS_OK')
LUA

export NVIM_SMOKE_DIAGNOSTIC_CONFIG="$SMOKE_TMP/diagnostic-config.lua"
cat > "$NVIM_SMOKE_DIAGNOSTIC_CONFIG" <<'LUA'
local function run()
  local severity = vim.diagnostic.severity
  local config = vim.diagnostic.config()

  assert(config.signs == false, 'diagnostic signs must stay disabled')

  assert(type(config.virtual_text) == 'table', 'virtual_text must stay configured as a table')
  local virtual_severity = config.virtual_text.severity
  assert(type(virtual_severity) == 'table' and virtual_severity.min == severity.ERROR,
    'virtual_text must be limited to ERROR severity')

  assert(type(config.underline) == 'table', 'underline must be severity filtered, not a bare boolean')
  local underline_severity = config.underline.severity
  assert(type(underline_severity) == 'table' and underline_severity.min == severity.WARN,
    'underline must cover WARN and ERROR')

  for _, name in ipairs({ 'DiagnosticSignError', 'DiagnosticSignWarn', 'DiagnosticSignInfo', 'DiagnosticSignHint' }) do
    assert(vim.tbl_isempty(vim.fn.sign_getdefined(name)),
      'obsolete diagnostic sign must not be defined: ' .. name)
  end

  local function check_highlights()
    for _, level in ipairs({ 'Error', 'Warn' }) do
      local hl = vim.api.nvim_get_hl(0, { name = 'DiagnosticUnderline' .. level, link = false })
      assert(hl.underline and not hl.undercurl and not hl.underdouble and not hl.underdotted and not hl.underdashed,
        level .. ' must use only a straight underline')
      assert(not hl.italic and hl.nocombine, level .. ' must not inherit italic syntax styling')
      for _, prefix in ipairs({ 'Diagnostic', 'DiagnosticVirtualText', 'DiagnosticSign', 'DiagnosticFloating' }) do
        assert(not vim.api.nvim_get_hl(0, { name = prefix .. level, link = false }).italic, prefix .. level .. ' must be upright')
      end
    end
    assert(not vim.api.nvim_get_hl(0, { name = 'DiagnosticUnnecessary', link = false }).italic,
      'unnecessary diagnostic tags must not reintroduce italics')
  end
  check_highlights()
  vim.cmd('colorscheme apollo')
  check_highlights()

  local prefix = config.virtual_text.prefix
  assert(type(prefix) == 'function', 'virtual_text prefix must stay a function')
  local error_prefix = prefix({ severity = severity.ERROR })
  local warn_prefix = prefix({ severity = severity.WARN })
  assert(type(error_prefix) == 'string' and error_prefix ~= '',
    'the error virtual-text prefix must resolve an icon')
  assert(error_prefix ~= warn_prefix,
    'the virtual-text prefix must keep the severity name lookup')
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cq')
end
LUA

export NVIM_SMOKE_DIAGNOSTIC_ECHO="$SMOKE_TMP/diagnostic-echo.lua"
cat > "$NVIM_SMOKE_DIAGNOSTIC_ECHO" <<'LUA'
local real_echo = vim.api.nvim_echo
local echoes = {}

local function echo_text(entry)
  local parts = {}
  for _, chunk in ipairs(entry.chunks) do
    parts[#parts + 1] = chunk[1]
  end
  return table.concat(parts)
end

local function find_since(index, predicate)
  for i = index + 1, #echoes do
    if predicate(echoes[i]) then
      return echoes[i]
    end
  end
  return nil
end

local function find_text(index, text)
  return find_since(index, function(entry)
    return echo_text(entry) == text
  end)
end

local function find_clear(index)
  return find_since(index, function(entry)
    return #entry.chunks == 0
  end)
end

local function run()
  local severity = vim.diagnostic.severity

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'first line holds three warnings plus an error',
    'second line holds a single warning',
    'third line holds only an error',
    'fourth line is clean',
  })
  vim.api.nvim_win_set_buf(0, buf)

  local ns = vim.api.nvim_create_namespace('smoke_diagnostic_echo')
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 9, severity = severity.WARN, message = 'second warning' },
    { lnum = 0, col = 2, severity = severity.WARN, message = 'first warning' },
    { lnum = 0, col = 2, severity = severity.WARN, message = 'tied warning' },
    { lnum = 0, col = 0, severity = severity.ERROR, message = 'an error' },
    { lnum = 0, col = 1, severity = severity.HINT, message = 'a hint' },
    { lnum = 1, col = 3, severity = severity.WARN, message = 'only warning' },
    { lnum = 1, col = 0, severity = severity.INFO, message = 'an info' },
    { lnum = 2, col = 0, severity = severity.ERROR, message = 'lonely error' },
  })

  local raw = vim.diagnostic.get(buf, { lnum = 0, severity = severity.WARN })
  assert(#raw == 3, 'the fixture must expose exactly three warnings on the first line')
  assert(raw[1].message == 'second warning',
    'the fixture assumes vim.diagnostic.get keeps insertion order so the column sort stays observable')

  vim.api.nvim_echo = function(chunks, history, opts)
    echoes[#echoes + 1] = { chunks = chunks, history = history, opts = opts }
  end

  local function move_to(line)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.api.nvim_exec_autocmds('CursorMoved', {})
  end

  local before = #echoes
  move_to(1)
  local first = find_text(before, '(1/3) first warning')
  assert(first, 'three warnings on one line must echo the lowest-column warning as (1/N)')
  assert(first.history == false, 'the warning echo must not enter :messages history')
  assert(not find_text(before, 'an error'), 'an ERROR must never displace the warning echo')
  assert(not find_text(before, 'a hint'), 'a HINT must never displace the warning echo')
  assert(not find_text(before, '(1/3) tied warning'),
    'warnings tied on col must keep vim.diagnostic.get order')

  before = #echoes
  move_to(2)
  local single = find_text(before, 'only warning')
  assert(single, 'a single warning must echo its message with no counter')
  assert(single.history == false, 'the warning echo must not enter :messages history')
  assert(not find_text(before, 'an info'), 'an INFO must never displace the warning echo')

  before = #echoes
  move_to(3)
  local error_cleared = find_clear(before)
  assert(error_cleared, 'an error-only line must clear the warning echo')
  assert(error_cleared.history == false, 'the clearing echo must not enter :messages history')
  assert(not find_text(before, 'lonely error'), 'an ERROR must never displace the warning echo')

  before = #echoes
  move_to(4)
  assert(find_clear(before), 'a clean line must clear the warning echo')

  before = #echoes
  move_to(1)
  before = #echoes
  vim.api.nvim_exec_autocmds('CursorHold', {})
  assert(find_text(before, '(1/3) first warning'), 'CursorHold must refresh the warning echo')

  before = #echoes
  vim.api.nvim_exec_autocmds('DiagnosticChanged', {})
  assert(find_text(before, '(1/3) first warning'),
    'DiagnosticChanged must refresh the warning echo even with no event data')

  before = #echoes
  vim.api.nvim_exec_autocmds('InsertEnter', {})
  assert(find_clear(before), 'InsertEnter must clear the warning echo')

  move_to(1)
  before = #echoes
  vim.api.nvim_exec_autocmds('BufLeave', {})
  assert(find_clear(before), 'BufLeave must clear the warning echo')

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  before = #echoes
  vim.fn.mode = function()
    return 'i'
  end
  vim.api.nvim_exec_autocmds('CursorMoved', {})
  vim.fn.mode = nil
  assert(not find_text(before, '(1/3) first warning'),
    'the warning echo must stay suppressed in insert mode')

  local events = {}
  for _, au in ipairs(vim.api.nvim_get_autocmds({ group = 'DiagnosticLineWarning' })) do
    events[au.event] = true
  end
  local names = vim.tbl_keys(events)
  table.sort(names)
  assert(table.concat(names, ',') == 'BufLeave,CursorHold,CursorMoved,DiagnosticChanged,InsertEnter',
    'the warning echo must bind exactly the refresh and clear events; got: ' .. table.concat(names, ','))

  local multiline_ns = vim.api.nvim_create_namespace('smoke_diagnostic_multiline')
  vim.diagnostic.set(multiline_ns, buf, {
    { lnum = 3, col = 0, severity = severity.WARN, message = 'multi\nline warning' },
  })
  before = #echoes
  move_to(4)
  assert(find_text(before, 'multi line warning'),
    'a multi-line warning must collapse onto one echo line')
end

local ok, err = xpcall(run, debug.traceback)
vim.api.nvim_echo = real_echo
vim.fn.mode = nil
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cq')
end
LUA

export NVIM_SMOKE_REPO="$REPO_DIR"

python3 "$REPO_DIR/scripts/smoke-probe.py" --self-test
python3 "$REPO_DIR/scripts/installer-regression.py"
for private in private.lua private_config.lua; do
  git check-ignore -q "lua/config/$private"
done

echo "== smoke matrix =="
nvim_probe "safe mappings, buffers, splits, previous tabs" +"lua dofile(vim.env.NVIM_SMOKE_REPO .. '/scripts/keymaps-regression.lua')"
# rows are appended by later tasks (insert above this marker)
assert_not_eager typescript-vim
assert_not_eager vim-javascript
assert_not_eager vim-graphql
assert_not_eager yats.vim
nvim_probe "TypeScript has no legacy Tsuquyomi client" +"lua assert(require('lazy.core.config').plugins.tsuquyomi == nil, 'legacy TypeScript client must not be installed')"
assert_not_eager vim-solidity
assert_loads_on_ft typescript-vim ts
assert_loads_on_ft vim-javascript  js
assert_loads_on_ft vim-graphql     graphql
assert_loads_on_ft yats.vim        ts
nvim_probe "TypeScript syntax does not start a legacy client" +"e scratch.ts" +"lua assert(vim.fn.exists(':TsuquyomiOpen') == 0, 'legacy TypeScript commands must remain absent')"
assert_loads_on_ft vim-solidity    sol
assert_not_eager typescript-tools.nvim
assert_loads_on_ft typescript-tools.nvim ts
assert_not_eager nvim-lspconfig
nvim_probe "nvim-lspconfig loads on BufReadPre" +"e README.md" +"lua $(loaded_lua nvim-lspconfig)"
assert_not_eager nvim-cmp
assert_loads_on_insert nvim-cmp
nvim_probe "nvim-treesitter is eager on main" +"lua $(loaded_lua nvim-treesitter)"
nvim_probe "Treesitter highlights and indents Lua, tolerates missing parsers" +"lua dofile(vim.env.NVIM_SMOKE_REPO .. '/scripts/treesitter-regression.lua')"
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
nvim_probe "Tagbar quit preserves files and tabs without layout-lock errors" +"lua dofile(vim.env.NVIM_SMOKE_REPO .. '/scripts/tagbar-regression.lua')"
assert_loads_on_cmd vim-trailing-whitespace FixWhitespace
assert_loads_on_cmd vim-easygrep            "GrepRoot ."
assert_loads_on_cmd ag.vim                  "AgFromSearch"
assert_not_eager ctrlsf.vim
assert_loads_on_cmd ctrlsf.vim CtrlSFToggle
assert_not_eager telescope.nvim
assert_loads_on_cmd telescope.nvim "Telescope find_files"
nvim_probe "neo-tree.nvim is eager (directory hijack ready at startup)" +"lua $(loaded_lua neo-tree.nvim)"
nvim_probe "opening files removes only unused empty unnamed buffers" +"lua dofile(vim.env.NVIM_SMOKE_EMPTY_BUFFER)"
nvim_probe "Bufferline detached clone updates main and writes its lockfile" +"lua dofile(vim.env.NVIM_SMOKE_REPO .. '/scripts/bufferline-update-regression.lua')"
nvim_probe "Bufferline formatter and indicator keep stable width" +"lua dofile(vim.env.NVIM_SMOKE_BUFFERLINE_CONFIG)"
nvim_probe "Top system strip preserves layout, focus, and telemetry" +"lua dofile(vim.env.NVIM_SMOKE_REPO .. '/scripts/topbar-regression.lua')"
nvim_probe "Bufferline header keyboard navigation preserves editor mappings" +"lua dofile(vim.env.NVIM_SMOKE_HEADER)"
nvim_probe "nvim <directory> settles to one persistent Neo-tree and focuses the editor" "$REPO_DIR" +"let g:smoke_case='startup'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
nvim_probe "directory startup quits once when clean and protects unsaved edits" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY_QUIT)"
nvim_probe "opening first Neo-tree file preserves tree and listed buffers" "$REPO_DIR" +"let g:smoke_case='first_file'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
nvim_probe "terminal splits below editor, appears in Bufferline, and closes with header x" "$REPO_DIR" +"let g:smoke_case='terminal'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
nvim_probe "closing last file preserves real Neo-tree and editor windows" "$REPO_DIR" +"let g:smoke_case='close_last'" +"lua dofile(vim.env.NVIM_SMOKE_DIRECTORY)"
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
nvim_probe "first search mapping loads Ag before exposing command completion" +"lua local a=vim.api; local map=vim.fn.maparg(',s','n',false,true); assert(type(map.callback)=='function'); local feed=a.nvim_feedkeys; local called=false; a.nvim_feedkeys=function(keys,mode,escape) assert(require('lazy.core.config').plugins['ag.vim']._.loaded); assert(a.nvim_get_commands({}).Ag.complete=='file'); assert(keys==':Ag ' and mode=='ni' and not escape); called=true end; local ok,err=pcall(map.callback); a.nvim_feedkeys=feed; assert(ok,err); assert(called)"
nvim_probe "fresh-process search completion handles first, repeated and fast input" +"lua dofile(vim.env.NVIM_SMOKE_SEARCH)"
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
nvim_probe "all highlights stay upright after theme, syntax, and plugin loads" +"lua dofile(vim.env.NVIM_SMOKE_UPRIGHT)"

nvim_probe "diagnostics: virtual text on errors, underline from warnings, no signs" +"e README.md" +"lua dofile(vim.env.NVIM_SMOKE_DIAGNOSTIC_CONFIG)"
nvim_probe "cursor-line warning echoes to the message area and clears" +"e README.md" +"lua dofile(vim.env.NVIM_SMOKE_DIAGNOSTIC_ECHO)"

echo
echo "== Intentionally eager (kept eager per user decision) =="
nvim_probe "lualine.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua lualine.nvim)"
nvim_probe "bufferline.nvim is eager (kept eager per user decision)" +"lua $(loaded_lua bufferline.nvim)"
nvim_probe "ultisnips is eager (kept eager per user decision)" +"lua $(loaded_lua ultisnips)"
# SMOKE_ROWS_END

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
