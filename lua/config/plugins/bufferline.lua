-- ====================================================================
-- Bufferline Configuration
-- ====================================================================

require('bufferline').setup({
  highlights = function(defaults)
    local highlights = defaults.highlights
    local background = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg or 'NONE'
    for _, group in pairs(highlights) do
      if group.bg ~= nil then group.bg = background end
    end
    highlights.buffer_selected = { fg = '#ffffff', bg = '#365b80', bold = true, italic = false }
    for _, name in ipairs({ 'separator', 'separator_visible', 'separator_selected' }) do
      highlights[name] = { fg = background, bg = name == 'separator_selected' and '#365b80' or background }
    end
    return highlights
  end,
  options = {
    mode = 'buffers',
    multiline = { enabled = true, max_rows = 3 },
    name_formatter = function(buf)
      local basename = vim.fn.fnamemodify(buf.path, ':t')
      return basename ~= '' and basename or buf.name
    end,
    show_buffer_icons = true,
    show_buffer_close_icons = false,
    close_command = require('config.keymaps').close_buffer,
    show_tab_indicators = false,
    show_close_icon = false,
    separator_style = 'slope',
    indicator = {
      style = 'icon',
      icon = ' ',
    },
    max_name_length = 16,
    tab_size = 16,
    enforce_regular_tabs = true,
    truncate_names = true,
    diagnostics = false,
    always_show_bufferline = true,
  },
})

require('config.topbar').setup()

local saved_cursor
local hidden_cursor = 'n-v:block-blinkon0-BufferlineHiddenCursor'
local group = vim.api.nvim_create_augroup('BufferlineHeaderCursor', { clear = true })

local function restore_cursor()
  if not saved_cursor then return end
  local applied = saved_cursor == '' and hidden_cursor or saved_cursor .. ',' .. hidden_cursor
  if vim.o.guicursor == applied then vim.o.guicursor = saved_cursor end
  saved_cursor = nil
end

local function update_cursor()
  local runtime = require('bufferline.multiline.runtime')
  if runtime.owns(vim.api.nvim_get_current_win()) then
    local background = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg or '#000000'
    vim.api.nvim_set_hl(0, 'BufferlineHiddenCursor', { fg = background, bg = background, blend = 100 })
    if not saved_cursor then
      saved_cursor = vim.o.guicursor
      vim.o.guicursor = saved_cursor == '' and hidden_cursor or saved_cursor .. ',' .. hidden_cursor
    end
  else
    restore_cursor()
  end
end

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'ColorScheme' }, {
  group = group,
  callback = update_cursor,
})
vim.api.nvim_create_autocmd({ 'WinLeave', 'VimLeavePre' }, {
  group = group,
  callback = restore_cursor,
})
