local api = vim.api
for _, case in ipairs({ 'last', 'tree', 'remaining', 'dirty', 'hidden-dirty', 'other-tab', 'toggle', 'utility', 'terminal', 'preview', 'unrelated-error', 'delayed' }) do
  local errors = {}
  local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-i', 'NONE', '-n',
    '--cmd', 'lua dofile(vim.env.NVIM_SMOKE_NO_INSTALL)', vim.env.NVIM_SMOKE_REPO .. '/lua/config/keymaps.lua' }, {
    rpc = true,
    on_stderr = function(_, lines) vim.list_extend(errors, lines) end,
  })
  local function lua(code, args) return vim.fn.rpcrequest(child, 'nvim_exec_lua', code, args or {}) end
  local ok, err = xpcall(function()
    assert(child > 0, 'Tagbar test process must start')
    lua([=[
      local api = vim.api
      editor, file, tab = api.nvim_get_current_win(), api.nvim_get_current_buf(), api.nvim_get_current_tabpage()
      vim.cmd('TagbarOpen')
      function tagbar_window()
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
          if vim.bo[api.nvim_win_get_buf(win)].filetype == 'tagbar' then return win end
        end
      end
      assert(vim.wait(2000, function() return tagbar_window() ~= nil end, 10), 'Tagbar must open')
      bar = tagbar_window()
      assert(vim.fn.maparg('<F9>', 'n') == ':TagbarToggle<CR>', 'Tagbar mapping must stay unchanged')
      api.nvim_set_current_win(editor)
    ]=])
    if case == 'tree' then
      lua("vim.cmd('Neotree show'); vim.wait(100); vim.api.nvim_set_current_win(editor)")
    elseif case == 'remaining' then
      lua("vim.cmd('split'); remaining = vim.api.nvim_get_current_win(); vim.api.nvim_set_current_win(editor)")
    elseif case == 'dirty' or case == 'hidden-dirty' or case == 'delayed' then
      lua("vim.api.nvim_buf_set_lines(file, 0, 1, false, { '-- keep unsaved Tagbar work' })")
      if case == 'hidden-dirty' then lua("vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))") end
    elseif case == 'other-tab' then
      lua([=[
        vim.cmd('tabnew')
        other_tab, other_win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
        vim.cmd('TagbarOpen')
        other_bar = tagbar_window()
        assert(other_bar)
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_set_current_win(editor)
      ]=])
    elseif case == 'toggle' then
      lua([=[
        for _ = 1, 2 do
          vim.cmd('TagbarToggle')
          assert(not tagbar_window())
          vim.cmd('TagbarToggle')
          assert(tagbar_window())
          vim.api.nvim_set_current_win(editor)
        end
        vim.cmd('Neotree show')
        vim.wait(100)
        vim.api.nvim_set_current_win(editor)
      ]=])
    elseif case == 'utility' or case == 'preview' then
      lua("vim.cmd('botright new'); utility = vim.api.nvim_get_current_win()")
      if case == 'utility' then lua("vim.bo.buftype = 'nofile'") else lua("vim.wo.previewwindow = true") end
    elseif case == 'terminal' then
      lua([=[
        vim.cmd('belowright new')
        terminal_win = vim.api.nvim_get_current_win()
        terminal_job = vim.fn.jobstart({ vim.v.progpath, '-u', 'NONE', '-i', 'NONE', '-n' }, { term = true })
        assert(terminal_job > 0)
        vim.api.nvim_set_current_win(editor)
      ]=])
    elseif case == 'unrelated-error' then
      lua("vim.api.nvim_create_autocmd('QuitPre', { once = true, callback = function() error('unrelated quit failure') end })")
    end
    if case == 'last' or case == 'tree' or case == 'toggle' then
      vim.fn.rpcrequest(child, 'nvim_input', ':q<CR>')
      local status = vim.fn.jobwait({ child }, 3000)[1]
      local messages = status == -1 and lua("return vim.api.nvim_exec2('messages', { output = true }).output") or ''
      assert(status == 0, 'one quit must exit a clean session: ' .. case .. '\n' .. tostring(messages))
    else
      lua([=[
        local case = ...
        local api = vim.api
        local quitting = api.nvim_get_current_win()
        local ok, err = pcall(function()
          if case == 'unrelated-error' then api.nvim_exec_autocmds('QuitPre', {}) else vim.cmd('quit') end
        end)
        if case == 'remaining' then
          assert(ok, err)
          assert(not api.nvim_win_is_valid(editor) and api.nvim_win_is_valid(remaining), 'only requested editor closes')
          assert(tagbar_window() == bar, 'Tagbar stays with remaining editor')
        elseif case == 'utility' or case == 'preview' then
          assert(ok, err)
          assert(not api.nvim_win_is_valid(utility) and api.nvim_win_is_valid(editor), 'only utility closes')
          assert(tagbar_window() == bar, 'utility quit must not close Tagbar')
        elseif case == 'terminal' then
          assert(ok, err)
          assert(not api.nvim_win_is_valid(editor) and api.nvim_win_is_valid(terminal_win), 'file quit preserves terminal')
          assert(not tagbar_window() and vim.fn.jobwait({ terminal_job }, 0)[1] == -1, 'Tagbar closes without stopping terminal job')
          vim.fn.jobstop(terminal_job)
        elseif case == 'unrelated-error' then
          local messages = api.nvim_exec2('messages', { output = true }).output
          assert(tostring(err):find('unrelated quit failure', 1, true) or messages:find('unrelated quit failure', 1, true), 'unrelated QuitPre errors must stay visible')
          assert(api.nvim_win_is_valid(editor) and api.nvim_get_current_win() == editor, 'failed quit retains editor')
        elseif case == 'other-tab' then
          assert(ok, err)
          assert(not api.nvim_tabpage_is_valid(tab), 'requested tab must close')
          assert(api.nvim_get_current_tabpage() == other_tab and api.nvim_win_is_valid(other_win), 'other tab survives')
          assert(tagbar_window() == other_bar, 'other tab Tagbar survives')
        else
          assert(not ok and tostring(err):find('E37', 1, true), 'native unsaved check must refuse quit: ' .. tostring(err))
          assert(api.nvim_get_current_win() == quitting, 'refused quit preserves original window')
          assert(vim.bo[file].modified and api.nvim_buf_get_lines(file, 0, 1, false)[1] == '-- keep unsaved Tagbar work', 'dirty text survives')
          assert(not tagbar_window(), 'last-editor quit closes Tagbar before native check')
          if case == 'delayed' then
            vim.cmd('tabnew')
            local next_tab, next_win = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
            api.nvim_buf_set_lines(0, 0, -1, false, { 'do not close this new window' })
            vim.wait(200)
            assert(api.nvim_get_current_tabpage() == next_tab and api.nvim_get_current_win() == next_win, 'no stale callback may quit another tab')
            assert(api.nvim_get_current_line() == 'do not close this new window' and vim.bo.modified, 'new work survives delayed events')
            api.nvim_set_current_tabpage(tab)
            api.nvim_set_current_win(quitting)
          end
          vim.cmd('TagbarToggle')
          assert(tagbar_window(), 'Tagbar must reopen after a refused quit')
        end
        vim.wait(100)
        local messages = api.nvim_exec2('messages', { output = true }).output
        assert(not messages:find('E1312', 1, true), messages)
      ]=], { case })
    end
    assert(not table.concat(errors, '\n'):find('E1312', 1, true), table.concat(errors, '\n'))
  end, debug.traceback)
  if child > 0 and vim.fn.jobwait({ child }, 0)[1] == -1 then vim.fn.jobstop(child) end
  assert(ok, case .. ': ' .. tostring(err))
end
print('TAGBAR_QUIT_REGRESSION_OK')
