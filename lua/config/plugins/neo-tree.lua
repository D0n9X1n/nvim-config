-- ====================================================================
-- Neo-tree Configuration
-- ====================================================================

local api = vim.api
local startup_editor = vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1
  and api.nvim_get_current_win() or nil

require('neo-tree').setup({
  close_if_last_window = true,
  event_handlers = {
    {
      event = 'neo_tree_window_after_open',
      handler = function(event)
        local editor = startup_editor
        if not editor or event.source ~= 'filesystem' then return end
        startup_editor = nil
        -- Neo-tree focuses its window after this event, so restore focus on the next turn.
        vim.schedule(function()
          if api.nvim_win_is_valid(editor) and api.nvim_get_current_win() == event.winid
            and api.nvim_win_get_tabpage(editor) == api.nvim_get_current_tabpage()
            and api.nvim_win_get_config(editor).relative == ''
            and vim.bo[api.nvim_win_get_buf(editor)].buftype == '' then
            api.nvim_set_current_win(editor)
          end
        end)
      end,
    },
  },
  open_files_do_not_replace_types = { 'terminal', 'Trouble', 'qf', 'edgy', 'bufferline' },
  popup_border_style = 'rounded',
  enable_git_status = true,
  enable_diagnostics = true,
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
