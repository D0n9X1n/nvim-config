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
local map = vim.keymap.set

-- Toggle chat
map('n', '<leader>cc', '<cmd>CopilotChatToggle<cr>', { desc = 'CopilotChat - Toggle' })

-- Quick chat with selection
map('v', '<leader>cc', '<cmd>CopilotChatToggle<cr>', { desc = 'CopilotChat - Toggle with selection' })

-- Predefined prompts
map('n', '<leader>ce', '<cmd>CopilotChatExplain<cr>', { desc = 'CopilotChat - Explain code' })
map('v', '<leader>ce', '<cmd>CopilotChatExplain<cr>', { desc = 'CopilotChat - Explain selection' })
map('n', '<leader>cr', '<cmd>CopilotChatReview<cr>', { desc = 'CopilotChat - Review code' })
map('v', '<leader>cr', '<cmd>CopilotChatReview<cr>', { desc = 'CopilotChat - Review selection' })
map('n', '<leader>cf', '<cmd>CopilotChatFix<cr>', { desc = 'CopilotChat - Fix code' })
map('v', '<leader>cf', '<cmd>CopilotChatFix<cr>', { desc = 'CopilotChat - Fix selection' })
map('n', '<leader>co', '<cmd>CopilotChatOptimize<cr>', { desc = 'CopilotChat - Optimize code' })
map('v', '<leader>co', '<cmd>CopilotChatOptimize<cr>', { desc = 'CopilotChat - Optimize selection' })
map('n', '<leader>ct', '<cmd>CopilotChatTests<cr>', { desc = 'CopilotChat - Generate tests' })
map('v', '<leader>ct', '<cmd>CopilotChatTests<cr>', { desc = 'CopilotChat - Generate tests for selection' })
