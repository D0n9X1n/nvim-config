-- ====================================================================
-- Plugin Specifications (lazy.nvim)
-- ====================================================================

return {
  -- Language Support
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('config.plugins.treesitter')
    end,
  },
  { 'leafgarland/typescript-vim' },
  { 'pangloss/vim-javascript' },
  { 'jparise/vim-graphql' },
  { 'HerringtonDarkholme/yats.vim' },
  { 'Quramy/tsuquyomi' },
  { 'tomlion/vim-solidity' },

  -- Formatter / Linting
  { 'gpanders/editorconfig.nvim' },
  { 'Chiel92/vim-autoformat' },

  -- Colorschemes
  { 'MOSconfig/vim-solarized8' },
  { 'MOSconfig/gruvbox' },
  { 'chriskempson/base16-vim' },
  { 'sainnhe/everforest' },
  { 'ayu-theme/ayu-vim' },

  -- HTML / CSS / Markdown
  {
    'NvChad/nvim-colorizer.lua',
    config = function()
      require('config.plugins.colorizer')
    end,
  },
  {
    'olrtg/nvim-emmet',
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
    build = 'cd app && npm install',
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    ft = { 'markdown' },
  },

  -- Tags / Navigation / Search
  { 'majutsushi/tagbar' },
  { 'bronson/vim-trailing-whitespace' },
  { 'Yggdroot/indentLine' },
  { 'dkprice/vim-easygrep' },
  { 'rking/ag.vim' },

  -- Completion & Snippets
  {
    'neovim/nvim-lspconfig',
    config = function()
      require('config.plugins.lsp')
    end,
  },
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
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
  { 'docunext/closetag.vim' },
  { 'Raimondi/delimitMate' },

  -- Editing Enhancements
  { 'junegunn/vim-easy-align' },
  { 'scrooloose/nerdcommenter' },
  {
    'tpope/vim-repeat',
    dependencies = { 'tpope/vim-surround' },
  },
  { 'luochen1990/rainbow' },
  { 'unblevable/quick-scope' },
  { 'terryma/vim-multiple-cursors' },
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },

  -- Movement
  { 'Lokaltog/vim-easymotion' },

  -- File Search / Navigation
  { 'dyng/ctrlsf.vim' },

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
    config = function()
      require('config.plugins.neo-tree')
    end,
  },

  -- Git Tools
  { 'tpope/vim-fugitive' },
  { 'airblade/vim-gitgutter' },

  -- Misc Tools
  { 'sjl/gundo.vim' },
  { 'MikeCoder/quickrun.vim' },
  {
    'gelguy/wilder.nvim',
    build = ':UpdateRemotePlugins',
    config = function()
      require('config.plugins.wilder')
    end,
  },
}
