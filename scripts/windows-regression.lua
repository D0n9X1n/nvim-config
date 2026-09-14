local root = assert(vim.env.NVIM_WINDOWS_REPO, 'NVIM_WINDOWS_REPO is required')
local mode = vim.env.NVIM_WINDOWS_TEST_MODE or 'unit'
local function eq(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. ': ' .. vim.inspect(actual))
end

local function unit()
  local has, executable, system = vim.fn.has, vim.fn.executable, vim.system
  local original = {}
  local options = { 'shell', 'shellcmdflag', 'shellpipe', 'shellredir', 'shellquote', 'shellxquote', 'shelltemp' }
  for _, name in ipairs(options) do original[name] = vim.o[name] end
  local ok, err = xpcall(function()
    for _, case in ipairs({
      { windows = true, pwsh = true, powershell = true, expected = 'pwsh' },
      { windows = true, pwsh = false, powershell = true, expected = 'powershell' },
      { windows = true, pwsh = false, powershell = false },
      { windows = false, pwsh = true, powershell = true },
    }) do
      for name, value in pairs(original) do vim.o[name] = value end
      vim.fn.has = function(feature)
        if feature == 'win32' or feature == 'win64' then return case.windows and 1 or 0 end
        return has(feature)
      end
      vim.fn.executable = function(command)
        if command == 'pwsh' or command == 'powershell' then return case[command] and 1 or 0 end
        return executable(command)
      end
      dofile(root .. '/lua/config/settings.lua')
      if case.expected then
        eq(vim.o.shell, case.expected, 'Windows shell preference')
        assert(vim.o.shellcmdflag:find('-NoProfile', 1, true), 'PowerShell must not load profiles')
        assert(vim.o.shellcmdflag:find('UTF8Encoding', 1, true), 'PowerShell encoding')
        eq(vim.o.shellquote, '', 'shellquote')
        eq(vim.o.shellxquote, '', 'shellxquote')
        eq(vim.o.shellpipe, '> %s 2>&1', 'shellpipe')
        eq(vim.o.shellredir, '> %s 2>&1', 'shellredir')
        eq(vim.o.shelltemp, false, 'PowerShell pipes')
      else
        for name, value in pairs(original) do eq(vim.o[name], value, 'unchanged ' .. name) end
      end
    end
    vim.fn.executable = executable
    local spec = dofile(root .. '/lua/plugins/init.lua')
    local preview
    for _, plugin in ipairs(spec) do
      if plugin[1] == 'iamcco/markdown-preview.nvim' then preview = plugin end
    end
    assert(preview and type(preview.build) == 'function', 'preview build missing')
    eq(preview.ft, { 'markdown' }, 'preview filetype preserved')
    eq(preview.cmd, { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' }, 'preview commands preserved')
    for _, windows in ipairs({ false, true }) do
      vim.fn.has = function(feature)
        if feature == 'win32' or feature == 'win64' then return windows and 1 or 0 end
        return has(feature)
      end
      local calls, status = 0, 0
      vim.system = function(command, opts)
        calls = calls + 1
        eq(command, windows and { 'cmd.exe', '/d', '/c', 'install.cmd' } or { 'bash', 'install.sh' }, 'preview platform command')
        eq(opts.cwd, 'fixture [space]/plugin/app', 'preview working directory')
        return { wait = function() return { code = status, stderr = 'injected build failure', stdout = '' } end }
      end
      preview.build({ dir = 'fixture [space]/plugin' })
      status = 7
      local success, failure = pcall(preview.build, { dir = 'fixture [space]/plugin' })
      assert(not success and tostring(failure):find('injected build failure', 1, true), 'build failure must propagate')
      eq(calls, 2, 'both builds awaited')
    end
  end, debug.traceback)
  vim.fn.has, vim.fn.executable, vim.system = has, executable, system
  for name, value in pairs(original) do vim.o[name] = value end
  assert(ok, err)
end

local function shell()
  assert(vim.fn.has('win32') == 1, 'real shell tests require native Windows')
  local requested = assert(vim.env.NVIM_WINDOWS_SHELL)
  assert(vim.fn.executable(requested) == 1, requested .. ' missing')
  local executable = vim.fn.executable
  vim.fn.executable = function(command)
    if requested == 'powershell' and command == 'pwsh' then return 0 end
    return executable(command)
  end
  dofile(root .. '/lua/config/settings.lua')
  vim.fn.executable = executable
  eq(vim.o.shell, requested, 'actual selected shell')
  local output = vim.fn.system("Write-Output 'powershell-ok'")
  eq(vim.v.shell_error, 0, 'PowerShell command exit')
  assert(output:find('powershell-ok', 1, true), 'PowerShell command output')
  local path = vim.fn.tempname() .. ' [space] ' .. vim.fn.nr2char(0x6d4b) .. '.txt'
  vim.fn.writefile({ 'unicode-path-ok' }, path)
  local result = vim.fn.system("Get-Content -LiteralPath '" .. path:gsub("'", "''") .. "'")
  vim.fn.delete(path)
  eq(vim.v.shell_error, 0, 'quoted path exit')
  assert(result:find('unicode-path-ok', 1, true), 'quoted Unicode path output')
  vim.cmd('enew')
  local buffer = vim.api.nvim_get_current_buf()
  local job = vim.fn.jobstart({ vim.o.shell, '-NoLogo', '-NoProfile', '-Command', "Write-Output 'terminal-ok'" }, {
    term = true,
  })
  assert(job > 0, 'PowerShell terminal must start')
  eq(vim.fn.jobwait({ job }, 15000)[1], 0, 'PowerShell terminal exit')
  assert(vim.wait(5000, function()
    return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n'):find('terminal-ok', 1, true)
  end, 20), 'terminal output')
end

local function integration()
  assert(vim.fn.has('win32') == 1, 'integration requires native Windows')
  eq(vim.g.colors_name, 'apollo', 'theme initialized')
  assert(vim.o.shell == 'pwsh' or vim.o.shell == 'powershell', 'Windows shell initialized')
  eq(vim.g.mapleader, ',', 'leader preserved')
  eq(vim.fn.maparg(',t', 'n'), ':split | terminal<CR>', 'terminal mapping preserved')
  assert(vim.fn.filereadable(vim.fn.stdpath('config') .. '/lua/config/private.lua') == 1, 'private stub exists')
  assert(vim.fn.has('python3') == 1, 'Python provider required')
  local plugins = require('lazy.core.config').plugins
  for _, name in ipairs({ 'nvim-apollo-theme', 'neo-tree.nvim', 'bufferline.nvim', 'lualine.nvim', 'ultisnips' }) do
    assert(plugins[name] and plugins[name]._.loaded, name .. ' must be eager')
  end
  require('lazy').load({ plugins = { 'telescope.nvim', 'markdown-preview.nvim' } })
  assert(type(require('telescope.builtin').find_files) == 'function', 'Telescope available')
  local preview = assert(plugins['markdown-preview.nvim'])
  local binary = preview.dir .. '/app/bin/markdown-preview-win.exe'
  assert(vim.fn.filereadable(binary) == 1, 'Windows Markdown preview binary missing')
  local version = vim.system({ binary, '--version' }, { text = true }):wait(15000)
  eq(version.code, 0, 'Windows Markdown preview binary runs')
  assert(version.stdout and version.stdout:match('%d+%.%d+'), 'preview version output')
  vim.cmd('enew')
  vim.cmd('setfiletype markdown')
  assert(vim.fn.exists(':MarkdownPreviewToggle') == 2, 'preview command available')
end

local ok, err = xpcall(function()
  if mode == 'unit' then unit()
  elseif mode == 'shell' then shell()
  elseif mode == 'integration' then integration()
  else error('unknown test mode: ' .. mode) end
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
if _G.smoke_finish then _G.smoke_finish() end
if vim.env.NVIM_WINDOWS_SUCCESS then vim.fn.writefile({ 'passed' }, vim.env.NVIM_WINDOWS_SUCCESS) end
print('PASS: Windows ' .. mode .. ' regressions')
vim.cmd('qa!')
