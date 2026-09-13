local failures = {}
local notify = vim.notify
vim.notify = function(message, level, options)
  if level and level >= vim.log.levels.ERROR then
    failures[#failures + 1] = tostring(message)
  end
  return notify(message, level, options)
end

local function fail(message)
  vim.api.nvim_err_writeln(message)
  vim.cmd('cquit 1')
end

_G.smoke_command = function(command)
  local ok, err = xpcall(function() vim.cmd(command) end, debug.traceback)
  if not ok then
    fail(err)
  end
end

_G.smoke_finish = function()
  vim.wait(50, function() return false end, 10)
  if #failures > 0 then
    fail(table.concat(failures, '\n'))
  end
  vim.fn.writefile({ 'passed' }, assert(vim.env.NVIM_SMOKE_SUCCESS))
end
