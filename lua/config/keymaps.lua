-- ====================================================================
-- Keymaps
-- ====================================================================

local map = vim.keymap.set
local opts = { noremap = true, silent = true }
local expr_opts = { noremap = true, silent = true, expr = true }

-- Helper functions
local function number_toggle()
  if vim.opt.relativenumber:get() then
    vim.opt.relativenumber = false
    vim.opt.number = true
  else
    vim.opt.relativenumber = true
  end
end

local function set_bg_color()
  if vim.opt.background:get() == 'dark' then
    vim.opt.background = 'light'
  else
    vim.opt.background = 'dark'
  end
end

local function close_buffer_smart()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs == 1 then
    vim.cmd('enew')
  else
    vim.cmd('bnext | bdelete #')
  end
end

-- Disable arrow keys in normal mode
map('n', '<Left>', '<Nop>', opts)
map('n', '<Right>', '<Nop>', opts)
map('n', '<Up>', '<Nop>', opts)
map('n', '<Down>', '<Nop>', opts)

-- Treat long lines as wrapped for j/k
map('n', 'k', 'gk', opts)
map('n', 'gk', 'k', opts)
map('n', 'j', 'gj', opts)
map('n', 'gj', 'j', opts)

-- F-key mappings
map('n', '<F1>', '<Esc>', opts)
map('n', '<F2>', ':Autoformat<CR>', opts)
map('n', '<F3>', ':Autoformat<CR>', opts)
map('n', '<F4>', ':set wrap! wrap?<CR>', opts)
map('n', '<F5>', ':QuickRun<CR>', opts)
map('n', '<F6>', function() number_toggle() end, { silent = true })
map('n', '<F7>', ':exec exists("syntax_on") ? "syn off" : "syn on"<CR>', opts)
map('n', '<F8>', ':IndentLinesToggle<CR>', opts)
map('n', '<F10>', ':set number! number?<CR>', opts)
map('n', '<F12>', ':GitGutterToggle<CR>', opts)

-- Leader mappings
map('n', '<leader>b', function() set_bg_color() end, { silent = true })
map('n', '<leader>af', ':Autoformat<CR>', opts)
map('n', '<leader>wr', ':set wrap! wrap?<CR>', opts)
map('n', '<leader>run', ':QuickRun<CR>', opts)
map('n', '<leader>rln', function() number_toggle() end, { silent = true })
map('n', '<leader>syn', ':exec exists("syntax_on") ? "syn off" : "syn on"<CR>', opts)
map('n', '<leader>il', ':IndentLinesToggle<CR>', opts)
map('n', '<leader>git', ':GitGutterToggle<CR>', opts)
map('n', '<leader>ln', ':set number! number?<CR>', opts)

-- Window navigation (splits)
map('n', '<C-j>', '<C-W>j', opts)
map('n', '<C-k>', '<C-W>k', opts)
map('n', '<C-h>', '<C-W>h', opts)
map('n', '<C-l>', '<C-W>l', opts)

-- Jump to start/end of line
map('n', 'H', '^', opts)
map('n', 'L', '$', opts)
map('v', 'H', '^', opts)
map('v', 'L', '$', opts)

-- Map ; to : for faster command entry
map('n', ';', ':', opts)

-- Search mappings
map('n', '<space>', '/', opts)
map('n', '/', '/\\v', opts)
map('v', '/', '/\\v', opts)

-- Keep search result centered
map('n', 'n', 'nzz', opts)
map('n', 'N', 'Nzz', opts)
map('n', '*', '*zz', opts)
map('n', '#', '#zz', opts)
map('n', 'g*', 'g*zz', opts)

-- Clear search highlight
map('n', '<leader>/', ':nohls<CR>', opts)

-- Swap * and #
map('n', '#', '*', opts)
map('n', '*', '#', opts)

-- Buffer navigation
map('n', '[b', ':bprevious<CR>', opts)
map('n', ']b', ':bnext<CR>', opts)
map('n', '<left>', ':bp<CR>', opts)
map('n', '<right>', ':bn<CR>', opts)
map('n', '<leader>q', function() close_buffer_smart() end, { silent = true })

-- Tab navigation
vim.g.last_active_tab = 1
map('n', '<leader>tt', function()
  vim.cmd('tabnext ' .. vim.g.last_active_tab)
end, { silent = true })
map('n', '<C-t>', ':tabnew<CR>', opts)
map('i', '<C-t>', '<Esc>:tabnew<CR>', opts)

-- Reselect after shifting indentation
map('v', '<', '<gv', opts)
map('v', '>', '>gv', opts)

-- Make Y behave like other capital motions
map('n', 'Y', 'y$', opts)

-- Select all
map('n', '<Leader>sa', 'ggVG', opts)

-- Write file using sudo when needed
map('c', 'w!!', 'w !sudo tee >/dev/null %', opts)

-- kj as <Esc> in insert mode
map('i', 'kj', '<Esc>', opts)

-- Faster scrolling
map('n', '<C-e>', '2<C-e>', opts)
map('n', '<C-y>', '2<C-y>', opts)

-- Fold current indent
map('n', '<leader>z', 'za', opts)

-- Force save with sudo
map('n', '<leader>w', ':w !sudo tee >/dev/null %<CR>', opts)

-- Swap ' and ` to make jumps easier
map('n', "'", '`', opts)
map('n', '`', "'", opts)

-- Remap U to redo
map('n', 'U', '<C-r>', opts)

-- Plugin specific mappings
map('n', '<leader>p', ':CtrlP<CR>', opts)
map('n', '<leader>f', ':CtrlPFunky<CR>', opts)
map('n', '<leader>n', ':NERDTreeToggle<CR>', opts)
map('n', '<leader>m', ':MarkdownPreviewToggle<CR>', opts)
map('n', '<leader>t', ':TagbarToggle<CR>', opts)
map('n', '<F9>', ':TagbarToggle<CR>', opts)
map('n', '<leader>us', ':UltiSnipsEdit<CR>', opts)
map('n', '<leader>jd', function() vim.lsp.buf.definition() end, opts)
map('n', '<leader>gd', function() vim.lsp.buf.declaration() end, opts)
map('n', '<leader>ee', function() vim.diagnostic.open_float() end, opts)
map('n', '<leader><space>', ':FixWhitespace<cr>', opts)
map('n', '<leader>s', ':Ag ', opts)
map('n', '\\', '<Plug>CtrlSFCwordPath<CR>', opts)
map('n', '<leader>a', '<Plug>(EasyAlign)', opts)
map('v', '<leader>a', '<Plug>(EasyAlign)', opts)

-- EasyMotion mappings
map('n', '<leader><leader>h', '<Plug>(easymotion-linebackward)', opts)
map('n', '<leader><leader>j', '<Plug>(easymotion-j)', opts)
map('n', '<leader><leader>k', '<Plug>(easymotion-k)', opts)
map('n', '<leader><leader>l', '<Plug>(easymotion-lineforward)', opts)
map('n', '<leader><leader>.', '<Plug>(easymotion-repeat)', opts)

-- Git helper
map('n', '<leader>g', ':!git add . && git commit -am "%" && git pull origin master && git push origin master<CR>', opts)

-- Command-line enhancements
map('c', '<C-j>', '<t_kd>', opts)
map('c', '<C-k>', '<t_ku>', opts)
map('c', '<C-a>', '<Home>', opts)
map('c', '<C-e>', '<End>', opts)
