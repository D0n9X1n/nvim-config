local api = vim.api
local M = {}
local started, pending, busy, paused = false, false, false, false
local native_tabline, rendered_tabline

function M.sample()
  local count = 0
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted and vim.bo[buf].modified then count = count + 1 end
  end
  return { host = vim.uv.os_gethostname() or 'localhost', unsaved = count }
end

function M.format(width, snapshot)
  snapshot = snapshot or M.sample()
  local count = snapshot.unsaved or 0
  local label = ' ' .. count
  local group = count > 0 and 'SystemBarUnsavedWarning' or 'SystemBarUnsaved'
  local right_size = vim.fn.strdisplaywidth(' ' .. label .. ' ')
  if right_size > width then return { { string.rep(' ', width), 'SystemBar' } } end
  local host = ''
  local host_width = math.min(24, width - right_size - 6)
  for _, char in ipairs(vim.fn.split((snapshot.host or ''):gsub('%c', ''), '\\zs')) do
    if vim.fn.strdisplaywidth(host .. char) > host_width then break end
    host = host .. char
  end
  local left_size = host ~= '' and vim.fn.strdisplaywidth(' ' .. host .. ' ') or 0
  local chunks = {}
  if host ~= '' then
    chunks[#chunks + 1] = { '', 'SystemBarHostEdge' }
    chunks[#chunks + 1] = { ' ' .. host .. ' ', 'SystemBarHost' }
    chunks[#chunks + 1] = { '', 'SystemBarHostEdge' }
  end
  chunks[#chunks + 1] = { string.rep(' ', width - left_size - right_size), 'SystemBar' }
  chunks[#chunks + 1] = { '', group .. 'Edge' }
  chunks[#chunks + 1] = { ' ' .. label .. ' ', group }
  chunks[#chunks + 1] = { '', group .. 'Edge' }
  return chunks
end

local function highlights()
  local normal = api.nvim_get_hl(0, { name = 'Normal', link = false })
  local selected = api.nvim_get_hl(0, { name = 'BufferLineBufferSelected', link = false })
  local red = api.nvim_get_hl(0, { name = 'DiagnosticError', link = false }).fg or 0xff3b30
  local background = normal.bg or 'NONE'
  local blue = selected.bg or 0x365b80
  api.nvim_set_hl(0, 'SystemBar', { fg = normal.fg, bg = background })
  api.nvim_set_hl(0, 'SystemBarHost', { fg = normal.bg or 0x141617, bg = red, bold = true })
  api.nvim_set_hl(0, 'SystemBarHostEdge', { fg = red, bg = background })
  api.nvim_set_hl(0, 'SystemBarUnsaved', { fg = selected.fg or 0xffffff, bg = blue, bold = true })
  api.nvim_set_hl(0, 'SystemBarUnsavedEdge', { fg = blue, bg = background })
  api.nvim_set_hl(0, 'SystemBarUnsavedWarning', { fg = 0x141617, bg = 0xfe8019, bold = true })
  api.nvim_set_hl(0, 'SystemBarUnsavedWarningEdge', { fg = 0xfe8019, bg = background })
end

local function minimum_height(layout)
  if layout[1] == 'leaf' then
    local win = layout[2]
    if vim.bo[api.nvim_win_get_buf(win)].filetype == 'bufferline' then return 3 end
    return math.max(1, vim.o.winminheight) + (vim.wo[win].winbar ~= '' and 1 or 0)
  end
  local height, count = 0, 0
  for _, child in ipairs(layout[2]) do
    local size = minimum_height(child)
    if size > 0 then
      count = count + 1
      height = layout[1] == 'row' and math.max(height, size) or height + size
    end
  end
  return height + (layout[1] == 'col' and math.max(0, count - 1) or 0)
end

function M.tabline(width, snapshot)
  local parts = {}
  for _, chunk in ipairs(M.format(width or vim.o.columns, snapshot)) do
    parts[#parts + 1] = '%#' .. chunk[2] .. '#' .. chunk[1]:gsub('%%', '%%%%')
  end
  return table.concat(parts)
end

local function render()
  local runtime = require('bufferline.multiline.runtime')
  if not runtime.selected() then
    if rendered_tabline and vim.o.tabline == rendered_tabline then vim.o.tabline = native_tabline end
    rendered_tabline = nil
    return
  end
  local editors = 0
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local kind = vim.bo[api.nvim_win_get_buf(win)].buftype
    if api.nvim_win_get_config(win).relative == '' and (kind == '' or kind == 'terminal') then editors = editors + 1 end
  end
  local available = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  local visible = not paused and editors > 0 and vim.o.lines >= 12 and available >= minimum_height(vim.fn.winlayout()) + 1
  rendered_tabline = M.tabline()
  if vim.o.tabline ~= rendered_tabline then vim.o.tabline = rendered_tabline end
  local show = visible and 2 or 0
  if vim.o.showtabline ~= show then vim.o.showtabline = show end
end

function M.refresh()
  if busy then return end
  busy = true
  local ok, err = pcall(render)
  busy = false
  if not ok then error(err) end
end

local function request()
  if paused or busy or pending then return end
  pending = true
  vim.schedule(function() pending = false; M.refresh() end)
end

function M.setup()
  if started then return end
  started = true
  native_tabline = vim.o.tabline
  highlights()
  local runtime = require('bufferline.multiline.runtime')
  local flush, disable = runtime.flush, runtime.disable
  -- Multiline hides the native tabline on every flush; reclaim it for the banner.
  runtime.flush = function(...)
    flush(...)
    M.refresh()
  end
  runtime.disable = function(...)
    disable(...)
    M.refresh()
  end
  local group = api.nvim_create_augroup('SystemBar', { clear = true })
  api.nvim_create_autocmd({ 'VimEnter', 'WinEnter', 'BufEnter', 'WinClosed', 'TabEnter', 'TabClosed', 'VimResized', 'BufModifiedSet', 'BufAdd', 'BufDelete', 'BufWipeout', 'BufUnload', 'BufWritePost' }, { group = group, callback = request })
  api.nvim_create_autocmd('OptionSet', { group = group, pattern = 'showtabline', callback = request })
  api.nvim_create_autocmd('ColorScheme', { group = group, callback = function() vim.schedule(function() highlights(); M.refresh() end) end })
  api.nvim_create_autocmd('SessionLoadPre', { group = group, callback = function() paused = true; M.refresh() end })
  api.nvim_create_autocmd('SessionLoadPost', { group = group, callback = function() paused = false; request() end })
  api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() paused = true end })
  request()
end

return M
