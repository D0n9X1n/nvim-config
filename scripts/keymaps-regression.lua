-- Run after loading tracked settings, keymaps and autocmds; never loads plugins.
-- Isolate view persistence even when called by the full smoke harness.
local api = vim.api
local viewdir = vim.fn.tempname()
vim.fn.mkdir(viewdir, 'p')
vim.opt.viewdir = viewdir

local function eq(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. ': expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual))
end

local function listed()
  return vim.tbl_map(function(info) return info.bufnr end, vim.fn.getbufinfo({ buflisted = 1 }))
end

local function reset()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) then vim.bo[buf].modified = false end
  end
  vim.cmd('silent tabonly')
  vim.cmd('silent only')
  local fresh = api.nvim_create_buf(true, false)
  api.nvim_set_current_buf(fresh)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if buf ~= fresh then api.nvim_buf_delete(buf, { force = false }) end
  end
  vim.g.last_active_tab = nil
  return fresh
end

local function named(buf)
  api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.txt')
  return buf
end

local function callback(lhs)
  local mapping = vim.fn.maparg(lhs, 'n', false, true)
  assert(type(mapping.callback) == 'function', lhs .. ' must be a Lua callback')
  return mapping.callback
end

local function close()
  callback(',q')()
end

local function assert_replaced(original, windows)
  local replacement = api.nvim_get_current_buf()
  assert(replacement ~= original, 'original buffer must be replaced')
  eq(listed(), { replacement }, 'exactly one listed replacement')
  eq(api.nvim_buf_get_name(replacement), '', 'replacement is unnamed')
  eq(api.nvim_buf_get_lines(replacement, 0, -1, false), { '' }, 'replacement is empty')
  assert(not vim.bo[replacement].modified, 'replacement is unmodified')
  assert(vim.fn.buflisted(original) == 0, 'original is unlisted')
  eq(api.nvim_tabpage_list_wins(0), windows, 'windows preserved')
  return replacement
end

local function assert_refused(buf)
  local win, tab = api.nvim_get_current_win(), api.nvim_get_current_tabpage()
  local buffers, windows = listed(), api.nvim_tabpage_list_wins(0)
  local alternate = vim.fn.bufnr('#')
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local cursor = api.nvim_win_get_cursor(win)
  local notifications, events = {}, 0
  local old_notify = vim.notify
  local group = api.nvim_create_augroup('KeymapsRegressionFocus', { clear = true })
  api.nvim_create_autocmd({ 'BufLeave', 'BufEnter', 'WinLeave', 'WinEnter' }, {
    group = group,
    callback = function() events = events + 1 end,
  })
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end
  local ok, err = pcall(close)
  vim.notify = old_notify
  api.nvim_del_augroup_by_id(group)
  assert(ok, err)
  eq(api.nvim_get_current_buf(), buf, 'modified buffer keeps focus')
  eq(api.nvim_get_current_win(), win, 'modified buffer keeps window')
  eq(api.nvim_get_current_tabpage(), tab, 'modified buffer keeps tab')
  eq(api.nvim_tabpage_list_wins(0), windows, 'modified buffer keeps splits')
  eq(listed(), buffers, 'modified buffer keeps listed state')
  eq(vim.fn.bufnr('#'), alternate, 'modified buffer keeps alternate buffer')
  eq(api.nvim_buf_get_lines(buf, 0, -1, false), lines, 'unsaved text preserved')
  eq(api.nvim_win_get_cursor(win), cursor, 'cursor preserved')
  assert(vim.bo[buf].modified, 'modified flag preserved')
  eq(events, 0, 'refusal does not trigger focus events')
  eq(#notifications, 1, 'refusal emits one warning')
  eq(notifications[1].level, vim.log.levels.WARN, 'warning severity')
  assert(type(notifications[1].message) == 'string' and #notifications[1].message > 0, 'warning explains refusal')
end

local function with_terminal(run)
  local buf = reset()
  local job = vim.fn.jobstart({ vim.v.progpath, '-u', 'NONE', '-i', 'NONE', '-n' }, { term = true })
  assert(job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1, 'terminal job must be running')
  local pid = vim.fn.jobpid(job)
  local ok, err = xpcall(function() run(buf, job, pid) end, debug.traceback)
  if vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
  assert(ok, err)
end

local function assert_terminal_closed(buf, job, pid)
  assert(vim.fn.buflisted(buf) == 0, 'terminal buffer must be removed')
  assert(vim.wait(3000, function()
    return vim.fn.jobwait({ job }, 0)[1] ~= -1 and not vim.uv.kill(pid, 0)
  end, 10), 'closing the terminal must stop its process')
end

local function open_terminal()
  callback(',t')()
end

local tests = {
  { 'terminal splits below the editor and preserves visible unsaved files', function()
    for _, from in ipairs({ 'editor', 'neo-tree', 'bufferline' }) do
      local file = named(reset())
      local editor = api.nvim_get_current_win()
      api.nvim_buf_set_lines(file, 0, -1, false, { 'unsaved file text' })
      local utility, utility_win
      if from ~= 'editor' then
        vim.cmd('vsplit')
        utility_win = api.nvim_get_current_win()
        utility = api.nvim_create_buf(false, true)
        vim.bo[utility].filetype = from
        api.nvim_win_set_buf(utility_win, utility)
        vim.wo[utility_win].winfixbuf = true
      end
      local windows = api.nvim_tabpage_list_wins(0)
      local terminal, job
      local ok, err = xpcall(function()
        open_terminal()
        terminal, job = api.nvim_get_current_buf(), vim.b.terminal_job_id
        local terminal_win = api.nvim_get_current_win()
        assert(terminal_win ~= editor, 'terminal must open in a new split, not take over the file window')
        eq(api.nvim_win_get_buf(editor), file, 'original file must remain visible in its window')
        local remaining = vim.tbl_filter(function(win) return win ~= terminal_win end, api.nvim_tabpage_list_wins(0))
        eq(remaining, windows, 'terminal must add exactly one split and preserve existing windows')
        local editor_pos = api.nvim_win_get_position(editor)
        local terminal_pos = api.nvim_win_get_position(terminal_win)
        assert(terminal_pos[1] > editor_pos[1], 'terminal must split below the editor')
        eq(terminal_pos[2], editor_pos[2], 'terminal must stay inside the editor area')
        eq(api.nvim_win_get_width(terminal_win), api.nvim_win_get_width(editor), 'terminal split must match editor width')
        eq(vim.bo[terminal].buftype, 'terminal', 'new split must display a terminal')
        assert(job and vim.fn.jobwait({ job }, 0)[1] == -1, 'terminal job must be running')
        assert(vim.bo[file].modified and vim.bo[file].buflisted, 'file stays listed and modified')
        eq(api.nvim_buf_get_lines(file, 0, -1, false), { 'unsaved file text' }, 'file contents survive')
        if utility then eq(api.nvim_win_get_buf(utility_win), utility, 'utility window is untouched') end
        api.nvim_set_current_win(editor)
        eq(api.nvim_get_current_buf(), file, 'returning to editor must show the original file')
      end, debug.traceback)
      if job and vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
      if terminal and vim.bo[terminal].buftype == 'terminal' then api.nvim_buf_delete(terminal, { force = true }) end
      if utility_win then vim.wo[utility_win].winfixbuf = false end
      assert(ok, err)
    end
  end },
  { 'terminal refuses when no unlocked editor is available', function()
    local file = named(reset())
    local windows = api.nvim_list_wins()
    vim.wo.winfixbuf = true
    local notify, warning = vim.notify, nil
    vim.notify = function(message) warning = message end
    local ok, err = pcall(open_terminal)
    vim.notify = notify
    vim.wo.winfixbuf = false
    assert(ok, err)
    assert(warning and warning:find('No unlocked editor', 1, true), 'terminal must explain a locked editor')
    eq(api.nvim_get_current_buf(), file, 'locked editor keeps its file')
    eq(api.nvim_list_wins(), windows, 'refusal must not add windows')
    eq(listed(), { file }, 'refusal must not create a terminal buffer')
  end },
  { 'non-terminal buffers never force deletion', function()
    for _, hidden in ipairs({ false, true }) do
      local buf = named(reset())
      if hidden then api.nvim_set_current_buf(named(api.nvim_create_buf(true, false))) end
      local delete, forced = api.nvim_buf_delete, nil
      api.nvim_buf_delete = function(target, options)
        if target == buf then forced = options.force end
        return delete(target, options)
      end
      local ok, err = pcall(require('config.keymaps').close_buffer, buf)
      api.nvim_buf_delete = delete
      assert(ok, err)
      eq(forced, false, 'ordinary buffer deletion must not use force')
      eq(vim.fn.buflisted(buf), 0, 'ordinary buffer must be closed')
    end
  end },
  { 'last running terminal leaves an empty buffer', function()
    with_terminal(function(buf, job, pid)
      local windows = api.nvim_tabpage_list_wins(0)
      close()
      assert_terminal_closed(buf, job, pid)
      assert_replaced(buf, windows)
    end)
  end },
  { 'hidden running terminal preserves editing context', function()
    with_terminal(function(buf, job, pid)
      local editor = named(api.nvim_create_buf(true, false))
      api.nvim_set_current_buf(editor)
      local win, windows = api.nvim_get_current_win(), api.nvim_list_wins()
      require('config.keymaps').close_buffer(buf)
      assert_terminal_closed(buf, job, pid)
      eq(api.nvim_get_current_win(), win, 'hidden close keeps focus')
      eq(api.nvim_get_current_buf(), editor, 'hidden close keeps editing buffer')
      eq(api.nvim_list_wins(), windows, 'hidden close keeps windows')
    end)
  end },
  { 'running terminal preserves splits across tabpages', function()
    with_terminal(function(buf, job, pid)
      local replacement = named(api.nvim_create_buf(true, false))
      local first = api.nvim_get_current_win()
      vim.cmd('vsplit')
      local second = api.nvim_get_current_win()
      vim.cmd('tab split')
      local third = api.nvim_get_current_win()
      local windows = api.nvim_list_wins()
      close()
      assert_terminal_closed(buf, job, pid)
      eq(api.nvim_list_wins(), windows, 'terminal close keeps all windows')
      for _, win in ipairs({ first, second, third }) do
        eq(api.nvim_win_get_buf(win), replacement, 'terminal view replaced')
      end
    end)
  end },
  { 'locked running terminal is refused without stopping its job', function()
    with_terminal(function(buf, job, pid)
      vim.wo.winfixbuf = true
      local old_notify, warning = vim.notify, nil
      vim.notify = function(message) warning = message end
      local ok, err = pcall(close)
      vim.notify = old_notify
      vim.wo.winfixbuf = false
      assert(ok, err)
      assert(warning and warning:find('locked window', 1, true), 'locked terminal must warn')
      eq(api.nvim_get_current_buf(), buf, 'locked terminal keeps its window')
      eq(vim.fn.jobwait({ job }, 0)[1], -1, 'locked terminal job keeps running')
      close()
      assert_terminal_closed(buf, job, pid)
    end)
  end },
  { 'last named clean buffer', function()
    local original = named(reset())
    local windows = api.nvim_tabpage_list_wins(0)
    close()
    local replacement = assert_replaced(original, windows)
    close()
    eq(api.nvim_get_current_buf(), replacement, 'repeated close is a no-op')
    eq(listed(), { replacement }, 'repeated close does not accumulate buffers')
  end },
  { 'last named modified buffer', function()
    local buf = named(reset())
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved' })
    assert_refused(buf)
  end },
  { 'multiple clean buffers choose next, not alternate', function()
    local original = named(reset())
    local next_buf = named(api.nvim_create_buf(true, false))
    local other = named(api.nvim_create_buf(true, false))
    api.nvim_set_current_buf(other)
    api.nvim_set_current_buf(original)
    local windows = api.nvim_tabpage_list_wins(0)
    close()
    eq(api.nvim_get_current_buf(), next_buf, 'next listed buffer selected')
    eq(listed(), { next_buf, other }, 'only exact original removed')
    eq(api.nvim_tabpage_list_wins(0), windows, 'windows preserved')
    close()
    eq(api.nvim_get_current_buf(), other, 'next close advances')
  end },
  { 'next buffer wraps and preserves unsaved replacement', function()
    local first = named(reset())
    api.nvim_buf_set_lines(first, 0, -1, false, { 'keep this unsaved text' })
    local original = named(api.nvim_create_buf(true, false))
    api.nvim_set_current_buf(original)
    close()
    eq(api.nvim_get_current_buf(), first, 'next wraps to first listed buffer')
    eq(listed(), { first }, 'only original removed on wrap')
    assert(vim.bo[first].modified, 'replacement modified flag preserved')
    eq(api.nvim_buf_get_lines(first, 0, -1, false), { 'keep this unsaved text' }, 'replacement text preserved')
  end },
  { 'multiple modified buffers preserve focus', function()
    local buf = named(reset())
    local other = named(api.nvim_create_buf(true, false))
    api.nvim_set_current_buf(other)
    api.nvim_buf_set_lines(other, 0, -1, false, { 'other unsaved' })
    api.nvim_set_current_buf(buf)
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'current unsaved' })
    assert_refused(buf)
    assert(vim.bo[other].modified, 'other modified buffer preserved')
  end },
  { 'sole unnamed empty buffer repeated close', function()
    local buf = reset()
    for _ = 1, 3 do close() end
    eq(api.nvim_get_current_buf(), buf, 'empty buffer identity preserved')
    eq(listed(), { buf }, 'no extra listed buffer')
  end },
  { 'unnamed modified buffer with splits', function()
    local buf = reset()
    vim.cmd('vsplit')
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved unnamed', 'keep cursor' })
    api.nvim_win_set_cursor(0, { 2, 3 })
    assert_refused(buf)
  end },
  { 'last file in same-buffer splits and tree window', function()
    local original = named(reset())
    local file_win = api.nvim_get_current_win()
    vim.cmd('vsplit')
    local second_win = api.nvim_get_current_win()
    vim.cmd('vsplit')
    local tree_win = api.nvim_get_current_win()
    local tree = api.nvim_create_buf(false, true)
    vim.bo[tree].filetype = 'neo-tree'
    api.nvim_win_set_buf(tree_win, tree)
    api.nvim_set_current_win(file_win)
    local windows = api.nvim_tabpage_list_wins(0)
    close()
    local replacement = assert_replaced(original, windows)
    eq(api.nvim_get_current_win(), file_win, 'file focus preserved')
    eq(api.nvim_win_get_buf(second_win), replacement, 'same-buffer split replaced')
    eq(api.nvim_win_get_buf(tree_win), tree, 'tree window unchanged')
  end },
  { 'multiple files in same-buffer splits', function()
    local original = named(reset())
    local next_buf = named(api.nvim_create_buf(true, false))
    vim.cmd('vsplit')
    local windows = api.nvim_tabpage_list_wins(0)
    local win = api.nvim_get_current_win()
    close()
    eq(api.nvim_tabpage_list_wins(0), windows, 'same-buffer splits preserved')
    eq(api.nvim_get_current_win(), win, 'focus preserved')
    for _, window in ipairs(windows) do
      eq(api.nvim_win_get_buf(window), next_buf, 'all original windows replaced')
    end
    eq(vim.fn.buflisted(original), 0, 'original unlisted')
  end },
  { 'previous tab absent and repeated switching', function()
    reset()
    local previous = callback(',tt')
    local first = api.nvim_get_current_tabpage()
    previous()
    eq(api.nvim_get_current_tabpage(), first, 'absent previous tab no-op')
    vim.cmd('tabnew')
    local second = api.nvim_get_current_tabpage()
    previous()
    eq(api.nvim_get_current_tabpage(), first, 'returns to first tab')
    previous()
    eq(api.nvim_get_current_tabpage(), second, 'repeated previous toggles tabs')
    previous()
    eq(api.nvim_get_current_tabpage(), first, 'toggle remains stable')
  end },
  { 'previous tab survives renumbering and closed target is a no-op', function()
    reset()
    local previous = callback(',tt')
    local first = api.nvim_get_current_tabpage()
    vim.cmd('tabnew')
    local second = api.nvim_get_current_tabpage()
    vim.cmd('tabnew')
    local third = api.nvim_get_current_tabpage()
    vim.cmd('tabclose ' .. api.nvim_tabpage_get_number(first))
    previous()
    eq(api.nvim_get_current_tabpage(), second, 'previous uses handle after renumbering')
    previous()
    eq(api.nvim_get_current_tabpage(), third, 'toggle returns to third')
    vim.cmd('tabclose ' .. api.nvim_tabpage_get_number(second))
    previous()
    eq(api.nvim_get_current_tabpage(), third, 'closed previous tab no-op')
  end },
  { 'safe mapping inventory', function()
    eq(vim.fn.maparg(',g', 'n'), '', 'unsafe git chain absent')
    eq(vim.fn.maparg(',w', 'n'), '', 'sudo save absent')
    eq(vim.fn.maparg('w!!', 'c'), '', 'command-line sudo absent')
    eq(vim.fn.maparg(',gs', 'n'), ':Git status<CR>', 'safe Git status mapping')
    eq(vim.fn.maparg(',wr', 'n'), ':set wrap! wrap?<CR>', 'wrap mapping preserved')
    callback(',t')
    for _, key in ipairs({ '<C-[>', '<C-]>' }) do
      local mapping = vim.fn.maparg(key, 't', false, true)
      eq(mapping.rhs, '<C-\\><C-n>', key .. ' exits terminal-input mode in one key')
      eq(mapping.noremap, 1, key .. ' is nonrecursive')
    end
    callback(',tt')
    eq(vim.fn.maparg('*', 'n'), '#zz', 'backward word search is centered')
    eq(vim.fn.maparg('#', 'n'), '*zz', 'forward word search is centered')
    eq(vim.fn.maparg('*', 'n', false, true).noremap, 1, 'word search is nonrecursive')
    eq(vim.fn.maparg('#', 'n', false, true).noremap, 1, 'word search is nonrecursive')
  end },
}

local ok, err = xpcall(function()
  for _, test in ipairs(tests) do
    local passed, failure = xpcall(test[2], debug.traceback)
    assert(passed, test[1] .. '\n' .. tostring(failure))
  end
  reset()
end, debug.traceback)
vim.fn.delete(viewdir, 'rf')
if not ok then
  api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
else
  print('KEYMAPS_REGRESSION_OK')
end
