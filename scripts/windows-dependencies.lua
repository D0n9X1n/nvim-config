local root = assert(vim.env.NVIM_WINDOWS_REPO)
local mode = vim.env.NVIM_WINDOWS_DEPENDENCIES_MODE or 'tools'
local function check(condition, message)
  assert(condition, message)
end
local function run(command, opts)
  local result = vim.system(command, vim.tbl_extend('force', { text = true }, opts or {})):wait(30000)
  check(result.code == 0, vim.inspect(command) .. ': ' .. (result.stderr or '') .. (result.stdout or ''))
  return result.stdout or ''
end
local function setup_shell()
  local requested = assert(vim.env.NVIM_WINDOWS_SHELL)
  dofile(root .. '/lua/config/settings.lua')
  check(vim.o.shell == requested, 'test must use requested PowerShell')
end
local function tools(temp)
  setup_shell()
  for _, command in ipairs({ 'ag', 'rg', 'fzf', 'ctags', 'node', 'npm', 'python', 'clang', 'clangd',
    'go', 'gopls', 'tree-sitter', 'tar', 'curl', 'prettier', 'tsserver', 'pyright-langserver',
    'bash-language-server', 'vscode-json-language-server', 'yaml-language-server', 'graphql-lsp',
    'vscode-solidity-server', 'lua-language-server', 'emmet-language-server' }) do
    check(vim.fn.executable(command) == 1, 'missing required dependency: ' .. command)
  end
  local file = temp .. '/search space.txt'
  vim.fn.writefile({ 'needle_windows_dependency', 'unrelated' }, file)
  check(run({ 'ag', '--nocolor', '--nogroup', 'needle_windows_dependency', file }):find('needle_windows_dependency', 1, true), 'ag search')
  check(run({ 'rg', '--no-heading', 'needle_windows_dependency', file }):find('needle_windows_dependency', 1, true), 'rg search')
  check(run({ 'fzf', '--filter=needle_windows_dependency' }, { stdin = 'unrelated\nneedle_windows_dependency\n' }):find('needle_windows_dependency', 1, true), 'fzf filter')
  for _, command in ipairs({ 'ag', 'rg' }) do
    local result = vim.system({ command, 'definitely_absent_pattern', file }, { text = true }):wait(15000)
    check(result.code == 1, command .. ' no-match must exit 1')
  end
  local source = temp .. '/sample.c'
  vim.fn.writefile({ 'int dependency_function(void) { return 42; }', 'int main(void) { return dependency_function() == 42 ? 0 : 1; }' }, source)
  local tags = run({ 'ctags', '-x', '--language-force=C', source })
  check(tags:find('dependency_function', 1, true), 'ctags must generate function tags')
  run({ 'clang', source, '-o', temp .. '/sample.exe' })
  run({ temp .. '/sample.exe' })
  require('lazy').load({ plugins = { 'ag.vim' } })
  vim.fn.setqflist({})
  vim.cmd('Ag needle_windows_dependency ' .. vim.fn.shellescape(file))
  local items = vim.fn.getqflist()
  check(#items == 1 and items[1].lnum == 1 and items[1].text:find('needle_windows_dependency', 1, true), 'Ag quickfix integration')
  vim.cmd('cclose')
  local formatted = vim.fn.system('prettier --parser typescript', 'const value={answer:42}\n')
  check(vim.v.shell_error == 0 and formatted:find('answer: 42', 1, true), 'Prettier through PowerShell')
  local archive = temp .. '/files.tar'
  run({ 'tar', '-cf', archive, '-C', temp, 'search space.txt' })
  check(run({ 'tar', '-tf', archive }):find('search space.txt', 1, true), 'tar archive roundtrip')
  local native = file:gsub('\\', '/')
  local content = run({ 'curl', '--fail', '--silent', '--show-error', 'file:///' .. native:gsub(' ', '%%20') })
  check(content:find('needle_windows_dependency', 1, true), 'curl local file transport')
  local ts = require('nvim-treesitter')
  ts.install({ 'c' }):wait(300000)
  local installed = vim.fn.stdpath('data') .. '/site/parser/c.so'
  check(vim.fn.filereadable(installed) == 1, 'C parser must be compiled and installed, not bundled fallback')
  vim.cmd('edit ' .. vim.fn.fnameescape(source))
  vim.bo.filetype = 'c'
  local parser = assert(vim.treesitter.get_parser(0, 'c'))
  parser:parse()
  vim.treesitter.start(0, 'c')
  local captures = vim.treesitter.get_captures_at_pos(0, 0, 0)
  check(#captures > 0, 'compiled C parser must produce highlight captures')
end
local function servers(temp)
  vim.fn.writefile({ 'module dependency.test/workspace', '', 'go 1.26' }, temp .. '/go.mod')
  vim.fn.writefile({ 'type Query { hello: String }' }, temp .. '/schema.graphql')
  vim.fn.writefile({ '{"schema":"schema.graphql"}' }, temp .. '/.graphqlrc.json')
  vim.fn.writefile({ '{"Lua.workspace.checkThirdParty":false}' }, temp .. '/.luarc.json')
  require('lazy').load({ plugins = { 'nvim-lspconfig' } })
  for _, name in ipairs({ 'pyright', 'gopls', 'clangd', 'bashls', 'jsonls', 'yamlls', 'graphql', 'solidity_ls', 'lua_ls' }) do
    local configured = assert(vim.lsp.config[name], name .. ' config missing')
    local config = vim.tbl_deep_extend('force', {}, configured, { name = name .. '-dependency-test', root_dir = temp,
      workspace_folders = { { uri = vim.uri_from_fname(temp), name = 'dependency-test' } },
      settings = name == 'lua_ls' and { Lua = { workspace = { checkThirdParty = false } } } or configured.settings,
    })
    config.on_attach, config.before_init, config.on_init = nil, nil, nil
    local id = assert(vim.lsp.start(config, { attach = false }), name .. ' failed to start')
    local client = assert(vim.lsp.get_client_by_id(id))
    local initialized = vim.wait(45000, function() return client.initialized or client:is_stopped() end, 50)
    local success = initialized and client.initialized and not client:is_stopped()
    client:stop(true)
    check(success, name .. ' did not complete LSP initialization')
    vim.wait(5000, function() return client:is_stopped() end, 20)
    print('PASS: ' .. name .. ' initialized')
  end
  local emmet = assert(vim.lsp.start({ name = 'emmet-dependency-test',
    cmd = { 'emmet-language-server', '--stdio' }, root_dir = temp }, { attach = false }))
  local client = assert(vim.lsp.get_client_by_id(emmet))
  vim.wait(30000, function() return client.initialized or client:is_stopped() end, 50)
  local initialized = client.initialized
  client:stop(true)
  check(initialized, 'Emmet language server initialization')
  local path = assert(vim.env.NVIM_DEPENDENCIES_NPM) .. '/node_modules/typescript/lib/tsserver.js'
  local output = {}
  local job = vim.fn.jobstart({ 'node', path }, {
    on_stdout = function(_, data) vim.list_extend(output, data) end,
    on_stderr = function(_, data) vim.list_extend(output, data) end,
  })
  check(job > 0, 'TypeScript server must start')
  vim.fn.chansend(job, vim.json.encode({ seq = 1, type = 'request', command = 'configure', arguments = {} }) .. '\n')
  local ready = vim.wait(30000, function()
    return table.concat(output, '\n'):find('"request_seq":1', 1, true) ~= nil
  end, 50)
  vim.fn.jobstop(job)
  check(ready and table.concat(output, '\n'):find('"success":true', 1, true), 'TypeScript server must respond to configure')
  print('PASS: Emmet and TypeScript servers initialized')
end
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
local ok, err = xpcall(function()
  check(vim.fn.has('win32') == 1, 'native Windows required')
  if mode == 'tools' then tools(temp)
  elseif mode == 'servers' then servers(temp)
  else error('unknown dependency test mode') end
end, debug.traceback)
vim.fn.delete(temp, 'rf')
if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end
if _G.smoke_finish then _G.smoke_finish() end
vim.fn.writefile({ 'passed' }, assert(vim.env.NVIM_WINDOWS_SUCCESS))
print('PASS: Windows dependencies ' .. mode)
vim.cmd('qa!')
