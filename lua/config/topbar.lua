local api, uv = vim.api, vim.uv
local M = {}
local namespace = api.nvim_create_namespace('SystemBar')
local windows, previous = {}, nil
local timer, pending, busy, paused = nil, false, false, false
local data = { host = uv.os_gethostname() or 'localhost', clock = os.date('%H:%M') }

local function clean(value)
  return tostring(value):gsub('%c', '')
end

local function fit(value, width)
  local result = ''
  for _, char in ipairs(vim.fn.split(clean(value), '\\zs')) do
    if vim.fn.strdisplaywidth(result .. char) > width then break end
    result = result .. char
  end
  return result
end

function M.format(width, snapshot)
  snapshot = snapshot or data
  if width < 14 then
    local host = fit(snapshot.host, width)
    return { { host .. string.rep(' ', width - vim.fn.strdisplaywidth(host)), 'SystemBarHost' } }
  end
  local host = fit(snapshot.host, math.min(24, width - 13))
  local left, right = ' ' .. host .. ' ', ' ' .. snapshot.clock .. ' '
  local available = width - vim.fn.strdisplaywidth(left .. right)
  local fields = { snapshot.cpu, snapshot.memory, snapshot.network }
  local middle = ''
  for _, field in ipairs(fields) do
    if field and vim.fn.strdisplaywidth(middle .. '  ' .. clean(field)) + 2 <= available then
      middle = middle .. '  ' .. clean(field)
    end
  end
  middle = middle .. string.rep(' ', math.max(0, available - vim.fn.strdisplaywidth(middle)))
  return {
    { '', 'SystemBarHostEdge' }, { ' ' .. host .. ' ', 'SystemBarHost' }, { '', 'SystemBarHostEdge' },
    { middle, 'SystemBar' },
    { '', 'SystemBarClockEdge' }, { ' ' .. snapshot.clock .. ' ', 'SystemBarClock' }, { '', 'SystemBarClockEdge' },
  }
end

function M.sample()
  local ok, cpus = pcall(uv.cpu_info)
  local total, idle = 0, 0
  if ok and cpus and #cpus > 0 then
    for _, cpu in ipairs(cpus) do
      for _, ticks in pairs(cpu.times) do total = total + ticks end
      idle = idle + cpu.times.idle
    end
    data.cpu = 'CPU --'
    if previous and total > previous.total and idle >= previous.idle then
      local usage = 100 * (1 - (idle - previous.idle) / (total - previous.total))
      data.cpu = ('CPU %.0f%%'):format(math.max(0, math.min(100, usage)))
    end
    previous = { total = total, idle = idle }
  else
    data.cpu, previous = 'CPU --', nil
  end
  local memory_ok, free = pcall(uv.get_free_memory)
  data.memory = memory_ok and type(free) == 'number' and ('FREE %.1f GiB'):format(free / 1024 ^ 3) or 'FREE --'
  local interfaces_ok, interfaces = pcall(uv.interface_addresses)
  local ipv4, other = {}, {}
  if interfaces_ok and interfaces then
    for name, addresses in pairs(interfaces) do
      for _, address in ipairs(addresses) do
        if not address.internal then
          other[name] = true
          if address.ip and not address.ip:find(':', 1, true) then ipv4[name] = true end
        end
      end
    end
  end
  local names = vim.tbl_keys(next(ipv4) and ipv4 or other)
  table.sort(names)
  data.network = 'NET ' .. (names[1] and fit(names[1], 12) or '--')
  data.clock = os.date('%H:%M')
  return vim.deepcopy(data)
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
  local inactive = api.nvim_get_hl(0, { name = 'BufferLineBackground', link = false })
  local selected = api.nvim_get_hl(0, { name = 'BufferLineBufferSelected', link = false })
  local red = api.nvim_get_hl(0, { name = 'DiagnosticError', link = false }).fg or 0xff3b30
  local background = normal.bg or 'NONE'
  api.nvim_set_hl(0, 'SystemBar', { fg = inactive.fg or normal.fg, bg = background })
  api.nvim_set_hl(0, 'SystemBarHost', { fg = normal.bg or 0x141617, bg = red, bold = true })
  api.nvim_set_hl(0, 'SystemBarClock', { fg = selected.fg or 0xffffff, bg = selected.bg or 0x365b80, bold = true })
  api.nvim_set_hl(0, 'SystemBarHostEdge', { fg = red, bg = background })
  api.nvim_set_hl(0, 'SystemBarClockEdge', { fg = selected.bg or 0x365b80, bg = background })
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
  if timer then return end
  highlights()
  M.sample()
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
  api.nvim_create_autocmd({ 'VimEnter', 'WinClosed', 'TabEnter', 'TabClosed', 'VimResized' }, { group = group, callback = request })
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
  timer = uv.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(function() if not paused then M.sample(); M.refresh() end end))
  api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() paused = true; timer:stop(); timer:close() end })
  request()
end

return M
