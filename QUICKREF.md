# Quick Reference Guide

## Leader Key: `,` (comma)

### Files & Navigation
- `,p` - Open file with CtrlP
- `,f` - Search functions with CtrlPFunky  
- `,n` - Toggle NERDTree
- `,s` - Search in files with Ag
- `\` - CtrlSF (search with context)

### Editing
- `,af` - Autoformat code
- `,<space>` - Fix trailing whitespace
- `,a` - EasyAlign (select text then press)
- `,/` - Clear search highlight

### Navigation
- `H` - Jump to line start
- `L` - Jump to line end
- `<C-h/j/k/l>` - Navigate between splits
- `[b`/`]b` - Previous/next buffer
- `<Left>`/`<Right>` - Previous/next buffer

### Development
- `,jd` - Go to definition (YCM)
- `,gd` - Go to declaration
- `,ee` - Show diagnostics
- `,t` or `<F9>` - Toggle Tagbar
- `,m` - Markdown preview
- `,us` - Edit snippets with UltiSnips

### Display
- `,b` - Toggle background (dark/light)
- `,ln` or `<F10>` - Toggle line numbers
- `,rln` or `<F6>` - Toggle relative line numbers
- `,wr` or `<F4>` - Toggle line wrapping
- `,syn` or `<F7>` - Toggle syntax highlighting
- `,il` or `<F8>` - Toggle indent guides

### Git
- `,git` or `<F12>` - Toggle GitGutter

### Insert Mode
- `<Tab>` - Expand snippet or complete
- `<S-Tab>` - Jump backward in snippet
- `<C-j>` - Jump forward or complete down
- `<C-k>` - Jump backward or complete up
- `kj` - Exit insert mode

### Search
- `/` - Search forward (very magic regex)
- `?` - Search backward
- `n`/`N` - Next/previous result (centered)
- `*`/`#` - Search for word under cursor

### Completion (YouCompleteMe)
- `<Down>`/`<Up>` - Navigate completions
- `<CR>` - Confirm completion
- `<C-k>` - Show documentation

### Multiple Cursors
- `<C-d>` - Select next occurrence
- `<C-p>` - Select previous occurrence
- `<C-j>` - Skip current occurrence
- `<Esc>` - Exit multi-cursor mode

## Quick Tips

1. **Record macros**: `qa...q` to record to register `a`, then `@a` to replay
2. **Sort lines**: `:%!sort` or visual select and `!sort`
3. **Build/Run**: `,run` or `<F5>` (for supported languages)
4. **Change colorscheme**: `:colorscheme everforest` (or gruvbox, solarized8, etc)
5. **Show command cheatsheet**: `:help index`

## Configuration Files

- `~/.config/nvim/lua/config/settings.lua` - General settings
- `~/.config/nvim/lua/config/keymaps.lua` - Key bindings
- `~/.config/nvim/lua/config/theme.lua` - Theme/appearance
- `~/.config/nvim/lua/plugins/init.lua` - Plugin list
- `~/.config/nvim/lua/config/private.lua` - Your customizations

## Useful Commands

```vim
:checkhealth          " Check health status
:Lazy                 " Plugin manager UI
:Lazy sync            " Sync all plugins
:Lazy update          " Update plugins
:TagbarToggle         " Toggle code outline
:NERDTreeToggle       " Toggle file tree
:MarkdownPreview      " Preview markdown
:Autoformat           " Format current file
:set number!          " Toggle line numbers
:UltiSnipsEdit        " Edit custom snippets
:YcmDiags             " Show all diagnostics
```

## File Extensions Setup

- `.lua` - Neovim config files
- `.json` - Lazy.nvim manifest
- `.md` - Documentation and snippets guide

Enjoy editing! 🎉
