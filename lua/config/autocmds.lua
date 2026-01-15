-- ====================================================================
-- Autocommands
-- ====================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- General autocmds
local general_group = augroup('General', { clear = true })

-- Leave Insert mode -> always disable paste mode
autocmd('InsertLeave', {
  group = general_group,
  command = 'set nopaste',
})

-- Close preview window on leaving Insert mode
autocmd('InsertLeave', {
  group = general_group,
  callback = function()
    if vim.fn.pumvisible() == 0 then
      vim.cmd('pclose')
    end
  end,
})

-- Reopen file at last edit position
autocmd('BufReadPost', {
  group = general_group,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Save and restore view (folds, cursor position etc.)
autocmd('BufWinLeave', {
  group = general_group,
  pattern = '*.*',
  command = 'silent! mkview',
})

autocmd('BufWinEnter', {
  group = general_group,
  pattern = '*.*',
  command = 'silent! loadview',
})

-- FileType specific settings
local filetype_group = augroup('FileTypeSettings', { clear = true })

autocmd('FileType', {
  group = filetype_group,
  pattern = 'cpp',
  command = 'set ts=2 sw=2 expandtab ai',
})

autocmd('FileType', {
  group = filetype_group,
  pattern = 'c',
  command = 'set ts=2 sw=2 expandtab ai',
})

autocmd('FileType', {
  group = filetype_group,
  pattern = 'javascript',
  command = 'set ts=2 sw=2 expandtab ai',
})

autocmd('FileType', {
  group = filetype_group,
  pattern = 'typescript',
  command = 'setlocal formatprg=prettier\\ --parser\\ typescript',
})

autocmd('FileType', {
  group = filetype_group,
  pattern = 'java',
  command = 'set ts=2 sw=2 expandtab ai',
})

autocmd({ 'BufRead', 'BufNewFile' }, {
  group = filetype_group,
  pattern = '*.md,*.mkd,*.markdown',
  command = 'set filetype=markdown',
})

autocmd({ 'BufRead', 'BufNewFile' }, {
  group = filetype_group,
  pattern = '*.part',
  command = 'set filetype=html',
})

-- Emmet for HTML/CSS
autocmd('FileType', {
  group = filetype_group,
  pattern = 'html,css',
  command = 'EmmetInstall',
})

-- Python # handling
autocmd({ 'BufNewFile', 'BufRead' }, {
  group = filetype_group,
  pattern = '*.py',
  command = 'inoremap # X<c-h>#',
})

-- Strip trailing whitespace on save
local strip_group = augroup('StripTrailingWhitespace', { clear = true })

local strip_whitespace = function()
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  vim.cmd('%s/\\s\\+$//e')
  vim.fn.cursor(line, col)
end

for _, filetype in ipairs({ 'c', 'cpp', 'java', 'go', 'php', 'javascript', 'puppet', 'python', 'rust', 'twig', 'xml', 'yml', 'perl' }) do
  autocmd('FileType', {
    group = strip_group,
    pattern = filetype,
    callback = function()
      autocmd('BufWritePre', {
        group = strip_group,
        buffer = 0,
        callback = strip_whitespace,
      })
    end,
  })
end

-- Highlight TODO / FIXME / NOTE / etc.
local todo_group = augroup('TodoHighlight', { clear = true })

autocmd('Syntax', {
  group = todo_group,
  pattern = '*',
  callback = function()
    if vim.fn.exists('syntax_on') == 1 then
      vim.fn.matchadd('Todo', '\\W\\zs\\(TODO\\|FIXME\\|CHANGED\\|DONE\\|XXX\\|BUG\\|HACK\\)')
      vim.fn.matchadd('Debug', '\\W\\zs\\(NOTE\\|INFO\\|IDEA\\|NOTICE\\)')
    end
  end,
})
