-- ====================================================================
-- Plugin Specifications (lazy.nvim)
-- ====================================================================

return {
  -- Language Support
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      require('config.plugins.treesitter')
    end,
  },
  { 'leafgarland/typescript-vim',     ft = { 'typescript', 'typescriptreact' } },
  { 'pangloss/vim-javascript',        ft = { 'javascript', 'javascriptreact' } },
  { 'jparise/vim-graphql',            ft = { 'graphql' } },
  { 'HerringtonDarkholme/yats.vim',   ft = { 'typescript', 'typescriptreact' } },
  { 'Quramy/tsuquyomi',               ft = { 'typescript' } },
  { 'tomlion/vim-solidity',           ft = { 'solidity' } },

  -- Formatter / Linting
  { 'gpanders/editorconfig.nvim', event = { 'BufReadPre', 'BufNewFile' } },
  {
    'Chiel92/vim-autoformat',
    cmd = 'Autoformat',
    keys = {
      { '<F3>',       ':Autoformat<CR>', desc = 'Autoformat', silent = true },
      { '<leader>af', ':Autoformat<CR>', desc = 'Autoformat', silent = true },
    },
  },

  -- Colorschemes
  { 'MOSconfig/vim-solarized8' },
  { 'MOSconfig/gruvbox' },
  { 'chriskempson/base16-vim' },
  { 'sainnhe/everforest' },
  { 'ayu-theme/ayu-vim' },
  {
    'MOSconfig/NeoSolarized.nvim',
  },

  -- HTML / CSS / Markdown
  {
    'NvChad/nvim-colorizer.lua',
    event = 'BufReadPost',
    config = function()
      require('config.plugins.colorizer')
    end,
  },
  {
    'olrtg/nvim-emmet',
    ft = { 'html', 'css', 'jsx', 'tsx', 'javascriptreact', 'typescriptreact' },
    config = function()
      require('config.plugins.emmet')
    end,
  },
  {
    'MeanderingProgrammer/markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    ft = { 'markdown' },
    config = function()
      require('config.plugins.markdown')
    end,
  },
  {
    'iamcco/markdown-preview.nvim',
    build = function(plugin)
      vim.system({ 'bash', 'install.sh' }, { cwd = plugin.dir .. '/app' }):wait()
    end,
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    ft = { 'markdown' },
  },

  -- Tags / Navigation / Search
  { 'majutsushi/tagbar', cmd = { 'TagbarToggle', 'TagbarOpen', 'Tagbar' } },
  { 'bronson/vim-trailing-whitespace', cmd = 'FixWhitespace' },

  { 'dkprice/vim-easygrep', cmd = { 'Grep', 'GrepRoot', 'GrepBuffer', 'Replace', 'ReplaceUndo' } },
  { 'rking/ag.vim', cmd = { 'Ag', 'AgAdd', 'AgFromSearch' } },

  -- Completion & Snippets
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('config.plugins.lsp')
    end,
  },
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ft = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
    config = function()
      require('config.plugins.typescript-tools')
    end,
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'quangnguyen30192/cmp-nvim-ultisnips',
      'SirVer/ultisnips',
    },
    event = { 'InsertEnter', 'CmdlineEnter' },
    config = function()
      require('config.plugins.cmp')
    end,
  },
  {
    'SirVer/ultisnips',
    dependencies = { 'honza/vim-snippets' },
    config = function()
      require('config.plugins.ultisnips')
    end,
  },
  { 'docunext/closetag.vim', ft = { 'html', 'xml', 'jsx', 'tsx' } },
  { 'Raimondi/delimitMate', event = 'InsertEnter' },

  -- Indent Guides
  {
    'nvimdev/indentmini.nvim',
    event = 'BufReadPost',
    config = function()
      require('config.plugins.indentmini')
    end,
  },

  -- Editing Enhancements
  {
    'junegunn/vim-easy-align',
    cmd = 'EasyAlign',
    keys = {
      { '<Plug>(EasyAlign)', mode = { 'n', 'x' } },
    },
  },
  { 'scrooloose/nerdcommenter', event = 'BufReadPost' },
  {
    'tpope/vim-repeat',
    dependencies = { 'tpope/vim-surround' },
    event = 'BufReadPost',
  },
  { 'luochen1990/rainbow', event = 'BufReadPost' },
  { 'unblevable/quick-scope', event = 'BufReadPost' },
  { 'terryma/vim-multiple-cursors', event = 'BufReadPost' },
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = 'BufReadPost',
  },

  -- Movement
  { 'Lokaltog/vim-easymotion', event = 'BufReadPost' },

  -- File Search / Navigation
  {
    'dyng/ctrlsf.vim',
    cmd = { 'CtrlSF', 'CtrlSFOpen', 'CtrlSFToggle' },
    keys = { { '\\', '<Plug>CtrlSFCwordPath<CR>', mode = 'n' } },
  },

  -- UI / Buffers
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('config.plugins.lualine')
    end,
  },
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('config.plugins.bufferline')
    end,
  },
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    keys = {
      { '<leader>p', ':Telescope find_files<CR>', desc = 'Find files',  silent = true },
      { '<leader>f', ':Telescope live_grep<CR>',  desc = 'Live grep',   silent = true },
      { '<leader>b', ':Telescope buffers<CR>',    desc = 'Buffers',     silent = true },
    },
    config = function()
      require('config.plugins.telescope')
    end,
  },
  -- File Tree
  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
      { '<leader>n', ':Neotree toggle<CR>', desc = 'Neo-tree toggle', silent = true },
    },
    config = function()
      require('config.plugins.neo-tree')
    end,
  },

  -- Git Tools
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gdiffsplit', 'Gread', 'Gwrite', 'Ggrep',
            'GMove', 'GDelete', 'GBrowse', 'GRemove', 'Gblame' },
  },
  { 'airblade/vim-gitgutter', event = 'BufReadPost' },

  -- Misc Tools
  { 'sjl/gundo.vim', cmd = 'GundoToggle' },
  { 'MikeCoder/quickrun.vim', cmd = 'QuickRun' },
  {
    'gelguy/wilder.nvim',
    build = ':UpdateRemotePlugins',
    event = 'CmdlineEnter',
    config = function()
      require('config.plugins.wilder')
    end,
  },
}
