-- ====================================================================
-- CopilotChat.nvim Configuration
-- ====================================================================

require('CopilotChat').setup({
  -- Default model
  model = 'claude-opus-4.6',

  -- Show help in virtual text
  show_help = true,

  -- Window layout
  window = {
    layout = 'vertical', -- 'vertical', 'horizontal', 'float', 'replace'
    width = 0.4,         -- fraction of screen width
  },

  -- Keymaps inside the chat buffer
  mappings = {
    complete = {
      detail = 'Use @<Tab> or /<Tab> for options.',
      insert = '<Tab>',
    },
    close = {
      normal = 'q',
      insert = '<C-c>',
    },
    reset = {
      normal = '<C-l>',
      insert = '<C-l>',
    },
    submit_prompt = {
      normal = '<CR>',
      insert = '<C-s>',
    },
  },
})

-- Global keymaps
vim.keymap.set({ 'n', 'v' }, '<F2>', '<cmd>CopilotChatToggle<cr>', { desc = 'CopilotChat - Toggle' })
