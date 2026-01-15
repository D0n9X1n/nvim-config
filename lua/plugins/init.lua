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
  { 'MikeCoder/markdown-preview.vim' },

  -- Tags / Navigation / Search
  { 'majutsushi/tagbar' },
  { 'bronson/vim-trailing-whitespace' },
  { 'Yggdroot/indentLine' },
  { 'dkprice/vim-easygrep' },
  { 'rking/ag.vim' },

  -- Completion & Snippets
  {
    'ycm-core/YouCompleteMe',
    build = './install.py --clang-completer',
    config = function()
      require('config.plugins.ycm')
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
  {
    'ctrlpvim/ctrlp.vim',
    dependencies = { 'tacahiroy/ctrlp-funky' },
  },
  { 'dyng/ctrlsf.vim' },

  -- UI / Buffers
  {
    'vim-airline/vim-airline',
    dependencies = { 'vim-airline/vim-airline-themes' },
    config = function()
      require('config.plugins.airline')
    end,
  },

  -- File Tree
  {
    'scrooloose/nerdtree',
    dependencies = { 'jistr/vim-nerdtree-tabs' },
  },

  -- Git Tools
  { 'tpope/vim-fugitive' },
  { 'airblade/vim-gitgutter' },

  -- Misc Tools
  { 'sjl/gundo.vim' },
  { 'MikeCoder/quickrun.vim' },
}
