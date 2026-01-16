-- ====================================================================
-- Plugin Specifications (lazy.nvim)
-- ====================================================================

return {
  -- Language Support
  { 'leafgarland/typescript-vim' },
  { 'pangloss/vim-javascript' },
  { 'jparise/vim-graphql' },
  { 'HerringtonDarkholme/yats.vim' },
  { 'Quramy/tsuquyomi' },
  { 'tomlion/vim-solidity' },

  -- Formatter / Linting
  { 'editorconfig/editorconfig-vim' },
  { 'Chiel92/vim-autoformat' },

  -- Colorschemes
  { 'MOSconfig/vim-solarized8' },
  { 'MOSconfig/gruvbox' },
  { 'chriskempson/base16-vim' },
  { 'sainnhe/everforest' },
  { 'ayu-theme/ayu-vim' },

  -- HTML / CSS / Markdown
  { 'ap/vim-css-color' },
  { 'mattn/emmet-vim' },
  { 'tpope/vim-markdown' },
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
    'j-morano/buffer_manager.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('config.plugins.buffer_manager')
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
