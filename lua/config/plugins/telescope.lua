-- ====================================================================
-- Telescope Configuration
-- ====================================================================

local ok, telescope = pcall(require, 'telescope')
if not ok then
  return
end

telescope.setup({
  defaults = {
    prompt_prefix = '󰍉 ',
    selection_caret = ' ',
    entry_prefix = '  ',
    layout_config = {
      width = 0.9,
      height = 0.8,
      prompt_position = 'top',
    },
    sorting_strategy = 'ascending',
  },
})
