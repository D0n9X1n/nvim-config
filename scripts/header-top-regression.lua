local api = vim.api
vim.o.lines = 40
vim.o.columns = 120
local runtime = require('bufferlines.multiline.runtime')
local function top()
  assert(vim.wait(1000, function()
    runtime.flush('header-top-test')
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    return handle and runtime.owns(handle.win) and api.nvim_win_get_position(handle.win)[1] == 0
  end, 10), 'buffer tabs must start on the first screen row')
  assert(vim.o.showtabline == 0, 'no native tabline row may sit above the buffer tabs')
  assert(vim.o.tabline == '%!v:lua.nvim_bufferlines()', 'native tabline must stay with Bufferline')
end
local function no_banner_state(when)
  assert(package.loaded['config.topbar'] == nil, 'top system banner must not load ' .. when)
  assert(not pcall(api.nvim_get_autocmds, { group = 'SystemBar' }), 'banner autocommands must not exist ' .. when)
  for name in pairs(api.nvim_get_hl(0, {})) do
    assert(not name:find('^SystemBar'), name .. ' highlight must not exist ' .. when)
  end
end
no_banner_state('at startup')
local editor = api.nvim_get_current_win()
for _ = 1, 3 do top() end
assert(api.nvim_get_current_win() == editor, 'header redraws must not steal focus')
api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved preview' })
top()
vim.bo.modified = false
for _, command in ipairs({ 'vsplit', 'split', 'tab split' }) do
  vim.cmd(command)
  top()
  vim.cmd(command == 'tab split' and 'tabclose' or 'close')
  top()
end
vim.cmd('Neotree show')
assert(vim.wait(1000, function()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'neo-tree' then return api.nvim_win_get_position(win)[1] == 0 end
  end
end, 10), 'Neo-tree must start on the first screen row')
api.nvim_set_current_win(editor)
top()
vim.cmd('Neotree close')
for _, width in ipairs({ 30, 80, 160, 120 }) do
  vim.o.columns = width
  top()
end
vim.o.lines = 8
runtime.flush('header-top-small')
assert(vim.o.showtabline == 0, 'tiny terminals must not show a native tabline row')
vim.o.lines = 40
top()
vim.cmd('colorscheme apollo')
top()
vim.wait(50)
no_banner_state('after colorscheme changes')
api.nvim_exec_autocmds('SessionLoadPre', {})
assert(vim.o.showtabline == 0, 'session loading must not show a native tabline row')
api.nvim_exec_autocmds('SessionLoadPost', {})
top()
assert(vim.o.laststatus == 3, 'bottom statusline stays unchanged')
runtime.disable()
assert(not runtime.selected() and vim.o.showtabline == 2, 'disabling multiline must show the native tabline')
assert(vim.o.tabline == '%!v:lua.nvim_bufferlines()', 'disabling multiline must restore native buffer tabs')
local native = api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = vim.o.columns }).str
assert(native:find('%S'), 'native buffer tabs must render entries')
local messages = api.nvim_exec2('messages', { output = true }).output
assert(not messages:find('E%d+:') and not messages:find('Error', 1, true), messages)
print('HEADER_TOP_REGRESSION_OK')
