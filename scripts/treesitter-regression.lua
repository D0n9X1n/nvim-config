-- Run after config loading; uses Neovim's bundled Lua parser, never installs one.
local function run()
  assert(vim.fn.has('nvim-0.12') == 1, 'Treesitter requires Neovim 0.12+')

  vim.cmd('enew!')
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'local function example()',
    'if true then',
    'return 1',
    'end',
    'end',
  })
  vim.bo[buf].shiftwidth = 2
  vim.bo[buf].tabstop = 2
  vim.bo[buf].expandtab = true
  vim.bo[buf].filetype = 'lua'

  local parser = assert(vim.treesitter.get_parser(buf), 'bundled Lua parser is unavailable')
  parser:parse()
  assert(vim.treesitter.highlighter.active[buf], 'Lua Treesitter highlighting is not active')
  local captures = vim.treesitter.get_captures_at_pos(buf, 0, 0)
  assert(vim.iter(captures):any(function(capture)
    return capture.capture:match('^keyword') ~= nil
  end), 'Lua local keyword has no Treesitter highlight capture')

  local queries = vim.api.nvim_get_runtime_file('queries/lua/indents.scm', true)
  assert(#queries > 0, 'Lua indent queries are absent from runtimepath')
  assert(vim.treesitter.query.get('lua', 'indents'), 'Lua indent queries cannot be parsed')
  assert(vim.bo[buf].indentexpr == "v:lua.require'nvim-treesitter'.indentexpr()",
    'Lua must use the main-branch Treesitter indentexpr')
  vim.cmd('normal! gg=G')
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), {
    'local function example()',
    '  if true then',
    '    return 1',
    '  end',
    'end',
  }), 'Treesitter did not reindent misindented Lua with two-space indentation')

  -- Only absent parsers may be skipped; unexpected core API failures must surface.
  local autocmd = assert(vim.api.nvim_get_autocmds({
    group = 'ConfigTreesitter', event = 'FileType',
  })[1], 'Treesitter FileType callback is missing')
  local get_parser = vim.treesitter.get_parser
  vim.treesitter.get_parser = function()
    error('treesitter-regression-api-failure')
  end
  local api_ok, api_err = pcall(autocmd.callback, { buf = buf })
  vim.treesitter.get_parser = get_parser
  assert(not api_ok and tostring(api_err):find('treesitter-regression-api-failure', 1, true),
    'unexpected Treesitter API failure was silently swallowed')

  vim.cmd('enew!')
  local missing_buf = vim.api.nvim_get_current_buf()
  vim.bo[missing_buf].indentexpr = '42'
  vim.bo[missing_buf].autoindent = true
  vim.bo[missing_buf].cindent = false
  vim.bo[missing_buf].smartindent = false
  vim.bo[missing_buf].shiftwidth = 3
  vim.bo[missing_buf].expandtab = false
  vim.bo[missing_buf].filetype = 'treesitter_regression_missing_parser'
  assert(vim.treesitter.get_parser(missing_buf) == nil, 'test filetype unexpectedly has a parser')
  assert(not vim.treesitter.highlighter.active[missing_buf], 'missing parser enabled highlighting')
  assert(vim.bo[missing_buf].indentexpr == '42', 'missing parser replaced existing indentexpr')
  assert(vim.bo[missing_buf].autoindent and not vim.bo[missing_buf].cindent
    and not vim.bo[missing_buf].smartindent and vim.bo[missing_buf].shiftwidth == 3
    and not vim.bo[missing_buf].expandtab, 'missing parser changed indentation options')

  local spec
  for _, candidate in ipairs(require('plugins')) do
    if candidate[1] == 'nvim-treesitter/nvim-treesitter' then
      spec = candidate
      break
    end
  end
  assert(spec and spec.lazy == false and spec.branch == 'main' and spec.event == nil,
    'Treesitter spec must eagerly load the explicit main branch')
  local lazy_config = package.loaded['lazy.core.config']
  if lazy_config then
    local plugin = lazy_config.plugins['nvim-treesitter']
    assert(plugin and plugin._.loaded and plugin.lazy == false and plugin.branch == 'main',
      'lazy.nvim did not eagerly load the Treesitter main branch')
  end
  print('PASS Treesitter: eager main, Lua highlight capture, runtime indent query, reindent, missing parser')
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
