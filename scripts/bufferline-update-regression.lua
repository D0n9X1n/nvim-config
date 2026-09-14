local function run()
  local spec
  for _, candidate in ipairs(dofile('lua/plugins/init.lua')) do
    if candidate[1] == 'MOSconfig/bufferline.nvim' then spec = candidate end
  end
  assert(spec and spec.branch == 'main', 'Bufferline must explicitly track main')
  assert(spec.tag == nil and spec.version == nil and spec.commit == nil, 'Bufferline must not be release-pinned')
  local git = require('lazy.manage.git')
  local task = require('lazy.manage.task.git')
  local config = require('lazy.core.config')
  local lock = require('lazy.manage.lock')
  local temp = vim.fn.tempname()
  vim.fn.mkdir(temp, 'p')
  local function command(args, cwd)
    local result = vim.system(args, { cwd = cwd, text = true, env = {
      GIT_AUTHOR_NAME = 'Regression', GIT_AUTHOR_EMAIL = 'test@example.invalid',
      GIT_COMMITTER_NAME = 'Regression', GIT_COMMITTER_EMAIL = 'test@example.invalid',
    } }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  local saved = { plugins = config.plugins, spec = config.spec, lockfile = config.options.lockfile,
    lock = lock.lock, loaded = lock._loaded }
  local ok, err = xpcall(function()
    local upstream, clone = temp .. '/upstream', temp .. '/old-clone'
    command({ 'git', 'init', '-q', '-b', 'main', upstream })
    vim.fn.writefile({ 'initial' }, upstream .. '/file')
    command({ 'git', 'add', 'file' }, upstream)
    command({ 'git', 'commit', '-qm', 'initial' }, upstream)
    command({ 'git', 'branch', 'legacy-feature' }, upstream)
    command({ 'git', 'clone', '-q', '--single-branch', '--branch', 'legacy-feature', upstream, clone })
    command({ 'git', 'checkout', '--detach', '-q' }, clone)
    command({ 'git', 'update-ref', '--no-deref', '-d', 'refs/remotes/origin/HEAD' }, clone)
    vim.fn.writefile({ 'latest main' }, upstream .. '/file')
    command({ 'git', 'commit', '-qam', 'main update' }, upstream)
    local plugin = { name = 'bufferline.nvim', dir = clone, branch = spec.branch, _ = { installed = true } }
    assert(git.get_branch({ dir = clone }) == nil, 'fixture must reproduce missing branch metadata')
    assert(not task.branch.skip(plugin), 'missing main must trigger lazy branch repair')
    task.branch.run({ plugin = plugin, spawn = function(_, executable, opts)
      local args = { executable }
      vim.list_extend(args, opts.args)
      command(args, opts.cwd)
    end })
    command({ 'git', 'fetch', '-q', 'origin' }, clone)
    local target = assert(git.get_target(plugin))
    assert(target.commit == command({ 'git', 'rev-parse', 'main' }, upstream), 'update must select latest main')
    command({ 'git', 'checkout', '--detach', '-q', target.commit }, clone)
    config.plugins = { ['bufferline.nvim'] = plugin }
    config.spec = { disabled = {}, ignore_installed = {} }
    config.options.lockfile = temp .. '/lazy-lock.json'
    lock.lock, lock._loaded = {}, false
    lock.update()
    local data = vim.json.decode(table.concat(vim.fn.readfile(config.options.lockfile), '\n'))
    assert(data['bufferline.nvim'].branch == 'main' and data['bufferline.nvim'].commit == target.commit,
      'lockfile must save valid latest-main metadata for detached clones')
  end, debug.traceback)
  config.plugins, config.spec, config.options.lockfile = saved.plugins, saved.spec, saved.lockfile
  lock.lock, lock._loaded = saved.lock, saved.loaded
  vim.fn.delete(temp, 'rf')
  assert(ok, err)
  print('PASS: Bufferline detached-clone update and lockfile regression')
end
local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
