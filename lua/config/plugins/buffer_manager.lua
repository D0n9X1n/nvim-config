-- ====================================================================
-- Buffer Manager Configuration
-- ====================================================================

require('buffer_manager').setup({
  borderchars = { '', '─', '', '│', '', '─', '', '│' },
  highlight = 'Normal:Normal',
})

local group = vim.api.nvim_create_augroup('BufferManagerRedraw', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'buffer_manager',
  callback = function(args)
    vim.api.nvim_create_autocmd('BufWinLeave', {
      group = group,
      buffer = args.buf,
      once = true,
      callback = function()
        vim.cmd('redraw!')
      end,
    })
  end,
})
