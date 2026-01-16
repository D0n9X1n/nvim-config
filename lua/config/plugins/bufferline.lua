-- ====================================================================
-- Bufferline Configuration
-- ====================================================================

require('bufferline').setup({
  options = {
    mode = 'buffers',
    numbers = 'buffer_id',
    close_command = 'bdelete! %d',
    right_mouse_command = 'bdelete! %d',
    left_mouse_command = 'buffer %d',
    middle_mouse_command = nil,
    indicator = {
      style = 'none',
    },
    buffer_close_icon = '',
    modified_icon = '',
    close_icon = '',
    left_trunc_marker = '',
    right_trunc_marker = '',
    name_formatter = function(buf)
      return vim.fn.fnamemodify(buf.name, ':t')
    end,
    max_name_length = 18,
    max_prefix_length = 15,
    truncate_mode = 'right',
    tab_size = 18,
    diagnostics = 'nvim_lsp',
    diagnostics_update_in_insert = false,
    offsets = {
      {
        filetype = 'NvimTree',
        text = 'File Explorer',
        text_align = 'left',
      },
    },
    show_buffer_icons = false,
    show_buffer_close_icons = false,
    show_close_icon = false,
    show_tab_indicators = false,
    persist_buffer_sort = true,
    separator_style = { '', '' },
    enforce_regular_tabs = false,
    always_show_bufferline = true,
  },
})
