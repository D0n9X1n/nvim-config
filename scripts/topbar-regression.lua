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
local runtime = require('bufferline.multiline.runtime')
local function rendered()
  return api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = vim.o.columns }).str
end
local function adjacent()
  assert(vim.wait(1000, function()
    runtime.flush('topbar-test')
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    return handle and runtime.owns(handle.win) and api.nvim_win_get_position(handle.win)[1] == 1
  end, 10), 'buffer tabs must immediately follow the banner without a blank separator row')
  assert(vim.o.showtabline == 2, 'banner must use exactly one native tabline row')
  assert(rendered() == text(topbar.format(vim.o.columns)), 'banner must fill the screen width')
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    assert(vim.bo[api.nvim_win_get_buf(win)].filetype ~= 'systembar', 'banner must not create a scratch split')
  end
  local header = assert(runtime.handles()[api.nvim_get_current_tabpage()])
  assert(api.nvim_win_get_position(header.win)[1] == 1, 'buffer tabs must immediately follow the banner without a blank separator row')
end
adjacent()
local escaped = api.nvim_eval_statusline(topbar.tabline(80, { host = 'host%#Error#name', unsaved = 0 }), { use_tabline = true, maxwidth = 80 })
assert(escaped.str == text(topbar.format(80, { host = 'host%#Error#name', unsaved = 0 })), 'hostname percent signs must be literal')
local editor = api.nvim_get_current_win()
for _ = 1, 5 do adjacent() end
assert(api.nvim_get_current_win() == editor, 'banner redraws must not steal focus')
local dirty_count = topbar.sample().unsaved
api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved preview' })
api.nvim_exec_autocmds('BufModifiedSet', { buffer = api.nvim_get_current_buf() })
assert(vim.wait(1000, function() return rendered():find(' ' .. (dirty_count + 1), 1, true) ~= nil end, 10), 'unsaved count must update after edits')
vim.bo.modified = false
api.nvim_exec_autocmds('BufModifiedSet', { buffer = api.nvim_get_current_buf() })
assert(vim.wait(1000, function() return rendered():find(' ' .. dirty_count, 1, true) ~= nil end, 10), 'saved count must update')
for _, command in ipairs({ 'vsplit', 'split', 'tab split' }) do
  vim.cmd(command)
  adjacent()
  vim.cmd(command == 'tab split' and 'tabclose' or 'close')
  adjacent()
end
vim.cmd('Neotree show')
assert(vim.wait(1000, function()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'neo-tree' then return api.nvim_win_get_position(win)[1] == 1 end
  end
end, 10), 'Neo-tree must start directly below the full-width banner')
api.nvim_set_current_win(editor)
adjacent()
vim.cmd('Neotree close')
vim.cmd('only')
adjacent()
for _, width in ipairs({ 30, 80, 160, 120 }) do
  vim.o.columns = width
  adjacent()
end
vim.o.lines = 8
runtime.flush('topbar-small')
assert(vim.o.showtabline == 0, 'tiny terminals must prioritize editing space')
vim.o.lines = 40
adjacent()
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
assert(vim.o.showtabline == 0, 'session loading hides the banner')
api.nvim_exec_autocmds('SessionLoadPost', {})
adjacent()
assert(vim.o.laststatus == 3, 'bottom statusline stays unchanged')
runtime.disable()
assert(vim.o.tabline == '%!v:lua.nvim_bufferline()', 'disabling multiline must restore native buffer tabs')
topbar.refresh()
assert(vim.o.tabline == '%!v:lua.nvim_bufferline()', 'banner must not reclaim the native renderer')
print('TOPBAR_REGRESSION_OK')
