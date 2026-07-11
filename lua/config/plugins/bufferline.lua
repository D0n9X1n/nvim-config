-- ====================================================================
-- Bufferline Configuration
-- ====================================================================

require('bufferline').setup({
  options = {
    mode = 'buffers',
    name_formatter = function(buf)
      local basename = vim.fn.fnamemodify(buf.path, ':t')
      return basename ~= '' and basename or buf.name
    end,
    offsets = {
      {
        filetype = 'neo-tree',
        text = '󰙅 Explorer',
        text_align = 'left',
      },
    },
    show_buffer_icons = true,
    show_buffer_close_icons = false,
    show_tab_indicators = true,
    separator_style = { '(', ')' },
    indicator = {
      style = 'icon',
      icon = ' ',
    },
    max_name_length = 16,
    tab_size = 16,
    diagnostics = false,
    always_show_bufferline = true,
  },
})
