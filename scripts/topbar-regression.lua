local api = vim.api
local topbar = require('config.topbar')
local function text(chunks)
  local parts = {}
  for _, chunk in ipairs(chunks) do parts[#parts + 1] = chunk[1] end
  return table.concat(parts)
end
for _, count in ipairs({ 0, 1, 12, 9999 }) do
  for width = 0, 160 do
    local chunks = topbar.format(width, { host = 'host%name', unsaved = count })
    local output = text(chunks)
    assert(vim.fn.strdisplaywidth(output) == width, 'top strip must fit width ' .. width)
    if #chunks == 7 then
      assert(chunks[2][2] == 'SystemBarHost', 'hostname must use the left red capsule')
      assert(chunks[4][1]:match('^  +$'), 'middle must contain only blank space')
      local group = count > 0 and 'SystemBarUnsavedWarning' or 'SystemBarUnsaved'
      assert(chunks[6][1] == '  ' .. count .. ' ' and chunks[6][2] == group, 'right capsule must warn only when the count is positive')
      assert(chunks[5][2] == group .. 'Edge' and chunks[7][2] == group .. 'Edge', 'slopes must match the counter color')
    end
    if width >= vim.fn.strdisplaywidth('  ' .. count .. ' ') then
      assert(output:sub(-#('  ' .. count .. ' ')) == '  ' .. count .. ' ', 'counter must be right-aligned even at zero')
    end
  end
end
local wide = topbar.format(80, { host = 'host%name', unsaved = 0 })
assert(#wide == 7 and text(wide):find(' host%%name ') == 1, 'hostname must remain on the left')
assert(text(wide):match('  0 $'), 'clean editor must keep the zero indicator visible')
for width = 0, 160 do
  vim.o.columns = math.max(12, width)
  local output = text(topbar.format(width, { host = '界界界界界\n', unsaved = 0 }))
  assert(vim.fn.strdisplaywidth(output) == width and not output:find('%c'), 'hostnames must be sanitized and fit narrow widths')
end

local baseline = topbar.sample().unsaved
local dirty = api.nvim_create_buf(true, false)
local utility = api.nvim_create_buf(false, true)
api.nvim_buf_set_lines(dirty, 0, -1, false, { 'unsaved unnamed buffer' })
api.nvim_buf_set_lines(utility, 0, -1, false, { 'utility text' })
vim.bo[utility].modified = true
assert(topbar.sample().unsaved == baseline + 1, 'listed unnamed edits count; unlisted utility buffers do not')
local original = api.nvim_get_current_buf()
api.nvim_set_current_buf(dirty)
vim.cmd('vsplit')
assert(topbar.sample().unsaved == baseline + 1, 'a buffer shown in multiple splits counts once')
vim.cmd('tab split')
assert(topbar.sample().unsaved == baseline + 1, 'a buffer shown in multiple tabs counts once')
vim.cmd('tabclose')
vim.cmd('close')
api.nvim_set_current_buf(original)
vim.bo[dirty].modified = false
assert(topbar.sample().unsaved == baseline, 'saved buffers must stop counting')
api.nvim_buf_delete(dirty, { force = true })
api.nvim_buf_delete(utility, { force = true })

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
assert(vim.wait(1000, function()
  local normal = api.nvim_get_hl(0, { name = 'Normal', link = false })
  local unsaved = api.nvim_get_hl(0, { name = 'SystemBarUnsaved', link = false })
  local host = api.nvim_get_hl(0, { name = 'SystemBarHost', link = false })
  local red = api.nvim_get_hl(0, { name = 'DiagnosticError', link = false }).fg
  local warning = api.nvim_get_hl(0, { name = 'SystemBarUnsavedWarning', link = false })
  return unsaved.bg == 0x365b80 and unsaved.fg == 0xffffff and unsaved.bold and host.bg == red
    and warning.bg == 0xfe8019 and warning.fg == 0x141617 and warning.bold
end, 10), 'hostname must be red and the unsaved counter blue')
api.nvim_exec_autocmds('SessionLoadPre', {})
assert(not bar(), 'session loading closes the scratch strip')
api.nvim_exec_autocmds('SessionLoadPost', {})
topbar.refresh()
assert(bar(), 'strip returns after session load')
assert(vim.o.showtabline == 0 and vim.o.laststatus == 3, 'native tabs and bottom statusline stay unchanged')
print('TOPBAR_REGRESSION_OK')
