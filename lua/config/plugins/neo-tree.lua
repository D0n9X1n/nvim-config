-- ====================================================================
-- Neo-tree Configuration
-- ====================================================================

local uv = vim.uv or vim.loop
local startup_path = vim.fn.argc() == 1 and vim.fn.fnamemodify(vim.fn.argv(0), ':p') or ''
local startup_stat = startup_path ~= '' and uv.fs_stat(startup_path) or nil
local clean_directory_replacement = startup_stat and startup_stat.type == 'directory'

require('neo-tree').setup({
  close_if_last_window = true,
  popup_border_style = 'rounded',
  enable_git_status = true,
  enable_diagnostics = true,
  event_handlers = clean_directory_replacement and {
    {
      event = 'file_opened',
      handler = function()
        if not clean_directory_replacement then
          return
        end
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(bufnr)
            and vim.bo[bufnr].buflisted
            and vim.api.nvim_buf_get_name(bufnr) == ''
            and not vim.bo[bufnr].modified then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end
        end
        clean_directory_replacement = false
      end,
    },
  } or nil,
  default_component_configs = {
    indent = {
      indent_size = 2,
      padding = 1,
      with_markers = true,
      expander_collapsed = '',
      expander_expanded = '',
      expander_highlight = 'NeoTreeExpander',
    },
    icon = {
      folder_closed = '',
      folder_open = '',
      folder_empty = '󰜌',
      default = '',
    },
    name = {
      trailing_slash = false,
      use_git_status_colors = true,
      highlight = 'NeoTreeFileName',
    },
    git_status = {
      symbols = {
        added = '',
        modified = '',
        deleted = '',
        renamed = '',
        untracked = '',
        ignored = '',
        unstaged = '',
        staged = '',
        conflict = '',
      },
    },
  },
  filesystem = {
    filtered_items = {
      visible = true,
      hide_dotfiles = false,
      hide_gitignored = false,
    },
    follow_current_file = {
      enabled = true,
    },
  },
  window = {
    position = 'left',
    width = 32,
    mappings = {
      ['<space>'] = 'toggle_node',
      ['<cr>'] = 'open',
      ['l'] = 'open',
      ['h'] = 'close_node',
    },
  },
})
