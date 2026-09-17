local api = vim.api
local topbar = require('config.topbar')
local function text(chunks)
  local parts = {}
  for _, chunk in ipairs(chunks) do parts[#parts + 1] = chunk[1] end
  return table.concat(parts)
end
local snapshot = { host = 'host%name', cpu = 'CPU 25%', memory = 'FREE 2.0 GiB', network = 'NET en0', clock = '12:34' }
for _, width in ipairs({ 1, 8, 12, 20, 40, 80, 160 }) do
  local output = text(topbar.format(width, snapshot))
  assert(vim.fn.strdisplaywidth(output) == width, 'top strip must fit width ' .. width)
end
local output = text(topbar.format(100, snapshot))
assert(output:find('host%%name') and output:find('CPU 25%%') and output:find('12:34', 1, true), 'literal text and metrics must survive')
assert(not text(topbar.format(25, snapshot)):find('NET', 1, true), 'network detail hides first on narrow screens')
snapshot.host = '界界界界界界界界界界'
assert(vim.fn.strdisplaywidth(text(topbar.format(24, snapshot))) == 24, 'wide hostnames stay bounded')

local saved = { cpu_info = vim.uv.cpu_info, get_free_memory = vim.uv.get_free_memory, interface_addresses = vim.uv.interface_addresses }
local ok, err = xpcall(function()
  vim.uv.cpu_info = function() return { { times = { user = 100, sys = 0, nice = 0, idle = 100, irq = 0 } } } end
  vim.uv.get_free_memory = function() return 2 * 1024 ^ 3 end
  vim.uv.interface_addresses = function() return { lo = { { internal = true, ip = '127.0.0.1' } }, en0 = { { internal = false, ip = '10.0.0.1' } } } end
  topbar.sample()
  vim.uv.cpu_info = function() return { { times = { user = 125, sys = 0, nice = 0, idle = 175, irq = 0 } } } end
  local data = topbar.sample()
  assert(data.cpu == 'CPU 25%' and data.memory == 'FREE 2.0 GiB' and data.network == 'NET en0', 'telemetry uses measured deltas and explicit units')
  vim.uv.cpu_info = function() return nil end
  vim.uv.get_free_memory = function() return nil end
  vim.uv.interface_addresses = function() return nil end
  data = topbar.sample()
  assert(data.cpu == 'CPU --' and data.memory == 'FREE --' and data.network == 'NET --', 'unavailable metrics must not claim zero or connectivity')
end, debug.traceback)
for name, fn in pairs(saved) do vim.uv[name] = fn end
assert(ok, err)

vim.o.lines = 40
vim.o.columns = 120
topbar.refresh()
local function bar()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'systembar' then return win end
  end
end
assert(vim.wait(1000, function() topbar.refresh(); return bar() ~= nil end, 10), 'top strip must appear')
local win = bar()
assert(api.nvim_win_get_position(win)[1] == 0 and api.nvim_win_get_width(win) == vim.o.columns, 'strip must sit across the top')
assert(api.nvim_win_get_height(win) == 1, 'strip is one row')
local visited = {}
_G.topbar_test_visit = function() visited[api.nvim_get_current_win()] = true end
vim.cmd('windo lua _G.topbar_test_visit()')
_G.topbar_test_visit = nil
for _, window in ipairs(api.nvim_tabpage_list_wins(0)) do
  assert(visited[window], 'windo must still visit each window')
end
local editing = api.nvim_get_current_win()
for _, command in ipairs({ 'wincmd t', 'wincmd k', 'wincmd w' }) do
  api.nvim_set_current_win(editing)
  vim.cmd(command)
  assert(vim.wait(1000, function() return api.nvim_get_current_win() ~= win end, 10), 'strip must reject focus from ' .. command)
end
api.nvim_set_current_win(win)
assert(vim.wait(1000, function() return api.nvim_get_current_win() ~= win end, 10), 'direct focus must return to an editing window')
api.nvim_set_current_win(editing)
assert(not vim.bo[api.nvim_win_get_buf(win)].buflisted, 'strip is not a buffer tab')
local runtime = require('bufferline.multiline.runtime')
for _ = 1, 5 do runtime.flush('topbar-test'); topbar.refresh() end
assert(bar() == win, 'redraws must not recreate the strip')
local editor = api.nvim_get_current_win()
vim.cmd('vsplit')
topbar.refresh()
assert(bar() == win and api.nvim_win_get_width(win) == vim.o.columns, 'splits preserve a single full-width strip')
vim.cmd('only')
assert(vim.wait(1000, function() topbar.refresh(); return bar() ~= nil end, 10), 'strip recovers after only')
vim.o.lines = 8
topbar.refresh()
assert(not bar(), 'tiny terminals must prioritize editing space')
vim.o.lines = 40
topbar.refresh()
assert(bar(), 'strip returns with enough space')
vim.cmd('colorscheme apollo')
topbar.refresh()
assert(vim.wait(1000, function() return api.nvim_get_hl(0, { name = 'SystemBarClock', link = false }).bg == 0x365b80 end, 10), 'clock must match blue active tabs')
api.nvim_exec_autocmds('SessionLoadPre', {})
assert(not bar(), 'session loading closes the scratch strip')
api.nvim_exec_autocmds('SessionLoadPost', {})
topbar.refresh()
assert(bar(), 'strip returns after session load')
assert(vim.o.showtabline == 0 and vim.o.laststatus == 3, 'native tabs and bottom statusline stay unchanged')
print('TOPBAR_REGRESSION_OK')
