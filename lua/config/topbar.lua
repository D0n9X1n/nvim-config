local api = vim.api
local M = {}
local namespace = api.nvim_create_namespace('SystemBar')
local windows = {}
local started, pending, busy, paused = false, false, false, false

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

local function owns(win)
  return win and api.nvim_win_is_valid(win) and vim.b[api.nvim_win_get_buf(win)].systembar == namespace
end

local function close(tab)
  local win = windows[tab]
  windows[tab] = nil
  if owns(win) then pcall(api.nvim_win_close, win, true) end
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
    if owns(win) then return 0 end
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

local function render()
  for tab, win in pairs(windows) do
    if not api.nvim_tabpage_is_valid(tab) or not owns(win) then windows[tab] = nil end
  end
  local tab = api.nvim_get_current_tabpage()
  local layout = vim.fn.winlayout()
  local editors = 0
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    local kind = vim.bo[api.nvim_win_get_buf(win)].buftype
    if api.nvim_win_get_config(win).relative == '' and (kind == '' or kind == 'terminal') then editors = editors + 1 end
  end
  local available = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  if editors == 0 or vim.o.lines < 12 or available < minimum_height(layout) + 2 then close(tab); return end
  local win = windows[tab]
  if not owns(win) then
    local buf = api.nvim_create_buf(false, true)
    vim.b[buf].systembar = namespace
    vim.bo[buf].filetype = 'systembar'
    vim.bo[buf].bufhidden = 'wipe'
    local ok
    ok, win = pcall(api.nvim_open_win, buf, false, { split = 'above', win = -1, height = 1, focusable = false, noautocmd = true })
    if not ok then api.nvim_buf_delete(buf, { force = true }); return end
    windows[tab] = win
    for name, value in pairs({
      winfixheight = true, winfixbuf = true, wrap = false, number = false, relativenumber = false,
      signcolumn = 'no', foldcolumn = '0', foldenable = false, winbar = '', statuscolumn = '',
      cursorline = false, cursorcolumn = false, spell = false, list = false, colorcolumn = '',
      winhighlight = 'Normal:SystemBar,EndOfBuffer:SystemBar', fillchars = 'horiz: ,horizup: ,horizdown: ',
    }) do vim.wo[win][name] = value end
  elseif layout[1] ~= 'col' or layout[2][1][1] ~= 'leaf' or layout[2][1][2] ~= win then
    api.nvim_win_set_config(win, { split = 'above', win = -1 })
  end
  if api.nvim_win_get_height(win) ~= 1 then api.nvim_win_set_height(win, 1) end
  local chunks = M.format(api.nvim_win_get_width(win))
  local parts = {}
  for _, chunk in ipairs(chunks) do parts[#parts + 1] = chunk[1] end
  local buf = api.nvim_win_get_buf(win)
  local line = table.concat(parts)
  if api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= line then
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  end
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  local column = 0
  for _, chunk in ipairs(chunks) do
    if #chunk[1] > 0 then api.nvim_buf_set_extmark(buf, namespace, 0, column, { end_col = column + #chunk[1], hl_group = chunk[2] }) end
    column = column + #chunk[1]
  end
end

function M.refresh()
  if paused or busy then return end
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
  highlights()
  local group = api.nvim_create_augroup('SystemBar', { clear = true })
  api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = group,
    callback = function()
      local entered = api.nvim_get_current_win()
      if owns(entered) then
        local target = vim.fn.win_getid(vim.fn.winnr('#'))
        -- Let :windo finish before changing its current window.
        vim.schedule(function()
          if paused or api.nvim_get_current_win() ~= entered or not owns(entered) then return end
          if not api.nvim_win_is_valid(target) or owns(target) or api.nvim_win_get_tabpage(target) ~= api.nvim_get_current_tabpage() then
            target = nil
            for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
              local kind = vim.bo[api.nvim_win_get_buf(win)].buftype
              if api.nvim_win_get_config(win).relative == '' and (kind == '' or kind == 'terminal') then target = win; break end
            end
          end
          if target then api.nvim_set_current_win(target) end
        end)
      end
      request()
    end,
  })
  api.nvim_create_autocmd({ 'VimEnter', 'WinClosed', 'TabEnter', 'TabClosed', 'VimResized', 'BufModifiedSet', 'BufAdd', 'BufDelete', 'BufWipeout', 'BufUnload', 'BufWritePost' }, { group = group, callback = request })
  api.nvim_create_autocmd('ColorScheme', { group = group, callback = function() vim.schedule(function() highlights(); M.refresh() end) end })
  api.nvim_create_autocmd('QuitPre', {
    group = group,
    callback = function()
      local tab = api.nvim_get_current_tabpage()
      local count = 0
      for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
        local kind = vim.bo[api.nvim_win_get_buf(win)].buftype
        if api.nvim_win_get_config(win).relative == '' and (kind == '' or kind == 'terminal') then count = count + 1 end
      end
      if count <= 1 then busy = true; close(tab); busy = false; request() end
    end,
  })
  api.nvim_create_autocmd('SessionLoadPre', { group = group, callback = function() paused = true; for tab in pairs(windows) do close(tab) end end })
  api.nvim_create_autocmd('SessionLoadPost', { group = group, callback = function() paused = false; request() end })
  api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() paused = true end })
  request()
end

return M
