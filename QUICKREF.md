# Neovim Configuration - Quick Reference & Project Structure

**A modern Neovim configuration ported from m-vim to lazy.nvim with Lua**

---

## 🧭 Agent Notes (Read First)

- **Primary entry**: `init.lua`
- **Plugin list**: `lua/plugins/init.lua`
- **Plugin configs**: `lua/config/plugins/`
- **Snippets**: `UltiSnips/` (UltiSnips format requires this directory name)
- **LSP config**: `lua/config/plugins/lsp.lua` uses `vim.lsp.config` (not `lspconfig.setup`)
- **Private plugins**: `lua/config/private.lua` (optional plugin list)
- **Private configs**: `lua/config/private_config.lua` (keymaps/settings/autocmds)

---

## 📁 Project Structure

### Complete File Hierarchy

```
nvim-config/
├── init.lua                    # Main entry point
├── install.sh                  # macOS installer script
├── .gitignore
├── README.md                   # Complete documentation
├── QUICKREF.md                 # This file - everything you need!
│
├── lua/
│   ├── config/
│   │   ├── settings.lua        # General vim settings
│   │   ├── keymaps.lua         # Keyboard mappings
│   │   ├── autocmds.lua        # Autocommands
│   │   ├── theme.lua           # Colorscheme & appearance
│   │   ├── private.lua         # Optional plugins (never overwritten)
│   │   ├── private_config.lua  # Personal keymaps/settings/autocmds
│   │   └── plugins/
│   │       ├── lsp.lua         # LSP config
│   │       ├── cmp.lua         # Completion config (nvim-cmp)
│   │       ├── ultisnips.lua   # UltiSnips config
│   │       ├── lualine.lua     # Statusline config
│   │       ├── bufferline.lua  # Bufferline config
│   │       ├── telescope.lua   # Telescope config
│   │       ├── neo-tree.lua    # File tree config
│   │       ├── typescript-tools.lua # TypeScript tools config
│   │       ├── treesitter.lua  # Treesitter config
│   │       ├── colorizer.lua   # Colorizer config
│   │       ├── emmet.lua       # Emmet config
│   │       ├── markdown.lua    # Markdown config
│   │       ├── wilder.lua      # Wilder config
│   │       └── config.lua      # Other plugins config
│   │
│   └── plugins/
│       └── init.lua            # Plugin specifications (lazy.nvim)
│
└── UltiSnips/                  # UltiSnips snippets (format expects this name)
    ├── all.snippets           # Global snippets (date, templates)
    ├── python.snippets        # Python (imports, functions, classes)
    ├── js.snippets            # JavaScript (console.log, React, CDN)
    ├── c.snippets             # C programming (loops, headers)
    ├── cpp.snippets           # C++ (algorithms, STL, ACM snippets)
    ├── go.snippets            # Go (functions, error handling)
    ├── php.snippets           # PHP (loops, utilities)
    └── snippets.snippets      # UltiSnips meta-snippets
```

### What's Included

#### 40+ Plugins Across 10 Categories

- **Language Support**: TypeScript, JavaScript, GraphQL, C/C++, Python, Solidity
- **Completion**: nvim-cmp, built-in LSP, UltiSnips, vim-snippets
- **Navigation**: neo-tree, Telescope, Tagbar, vim-easymotion
- **Version Control**: vim-fugitive, vim-gitgutter
- **UI Enhancements**: lualine, bufferline, wilder, indentLine, rainbow
- **Formatting**: vim-autoformat, EditorConfig
- **Editing**: vim-surround, vim-repeat, nerdcommenter, EasyAlign
- **Themes**: Gruvbox, Solarized, Everforest, Base16, Ayu
- **Search**: Ag.vim, CtrlSF, vim-easygrep
- **Utilities**: Markdown preview, QuickRun, Gundo, Wakatime (optional)

#### Key Features

✅ All original m-vim keybindings preserved  
✅ Modern lazy.nvim plugin manager  
✅ Lua configuration (clean, maintainable)  
✅ 40+ organized plugins  
✅ Full TypeScript/JavaScript support  
✅ LSP completion with snippets  
✅ Git integration  
✅ File tree and fuzzy search  
✅ Code formatting and linting  
✅ Multiple color schemes  

---

## 🚀 Quick Start

```bash
# 1. Run installer
./install.sh

# 2. Open Neovim
nvim

# 3. Plugins auto-install on first run
# 4. Optional: install language servers you use (e.g. clangd, pyright)
```

---

## ⌨️ Keyboard Shortcuts (Leader Key: `,`)

### Files & Navigation
- `,p` - Telescope find files
- `,f` - Telescope live grep
- `,n` - Toggle neo-tree
- `,s` - Search in files with Ag
- `,b` - Telescope buffers
- `\` - CtrlSF (search with context)

### Editing
- `,af` - Autoformat code
- `,<space>` - Fix trailing whitespace
- `,a` - EasyAlign (select text then press)
- `,/` - Clear search highlight
- `<F2>` / `<F3>` | Autoformat code

### Navigation & Movement
- `H` - Jump to line start
- `L` - Jump to line end
- `<C-h/j/k/l>` - Navigate between splits
- `[b` / `]b` - Previous/next buffer
- `<Left>` / `<Right>` - Previous/next buffer
- `k` / `j` - Move cursor (wrapped lines treated as normal)
- `;` - Faster command entry (mapped to `:`)

### Development & LSP
- `,jd` - Go to definition (LSP)
- `,gd` - Go to declaration (LSP)
- `,ee` - Show diagnostics (LSP)
- `,t` / `,tt` - Open split terminal
- `<F9>` - Toggle Tagbar
- `,m` - Markdown preview
- `,us` - Edit snippets with UltiSnips
- `,run` / `<F5>` - Quick run code

### Display & UI
- `,bg` - Toggle background (dark/light)
- `,ln` / `<F10>` - Toggle line numbers
- `,rln` / `<F6>` - Toggle relative line numbers
- `,wr` / `<F4>` - Toggle line wrap
- `,syn` / `<F7>` - Toggle syntax highlighting
- `,il` / `<F8>` - Toggle indent guides

### Git Integration
- `,git` / `<F12>` - Toggle GitGutter
- `,g` - Git: add, commit, pull, push (automated)

### Snippets & Completion (Insert Mode)
- `<Tab>` - Expand snippet or complete
- `<S-Tab>` - Jump backward in snippet
- `<C-j>` - Jump forward or complete down
- `<C-k>` - Jump backward or complete up
- `kj` - Exit insert mode

### Search & Find
- `/` - Search forward (very magic regex)
- `?` - Search backward
- `n` / `N` - Next/previous result (centered)
- `*` / `#` - Search for word under cursor
- `g*` - Search (no word boundary)

### Multiple Cursors
- `<C-d>` - Select next occurrence
- `<C-p>` - Select previous occurrence
- `<C-j>` - Skip current occurrence
- `<Esc>` - Exit multi-cursor mode

### EasyMotion
- `,,h` - EasyMotion backward
- `,,j` - EasyMotion down
- `,,k` - EasyMotion up
- `,,l` - EasyMotion forward
- `,,.` - Repeat last motion

### Miscellaneous
- `U` - Redo (mapped from `<C-r>`)
- `'` / `` ` `` - Swap to make jumps easier
- `Y` - Yank to end of line (like `D`, `C`)
- `<leader>z` - Toggle fold
- `<leader>w` - Force save with sudo
- `<leader>sa` - Select all
- `<leader>q` - Smart close buffer
- `<C-t>` - New tab
- `<F1>` - Escape (alternative)

### Command-Line Mode
- `<C-a>` - Go to start of line
- `<C-e>` - Go to end of line
- `<C-j>` - Navigate down
- `<C-k>` - Navigate up
- `w!!` - Write with sudo (`:w!!`)

---

## 🎨 Colorschemes

**Available colorschemes** - Switch with `:colorscheme name`

- **gruvbox** (default) - Retro groove color scheme
- **solarized8** - Precision colors for machines and people
- **solarized8_flat** - Solarized without background contrast
- **everforest** - Green-based color scheme
- **base16-default-dark** - Base16 default dark theme
- **ayu** - Modern theme (dark, light, mirage variants)

---

## 📊 Statistics

- **Lua Config Files**: 11
- **Total Plugins**: 40+
- **Snippet Files**: 8 (all included!)
- **Configuration Lines**: 2000+
- **Startup Time**: 50-100ms
- **Total Size (before plugins)**: ~300KB

---

## 📍 Installation Locations

```
~/.config/nvim/           # Main configuration
~/.local/share/nvim/lazy/ # Plugins (auto-installed on first run)
~/.config/nvim/UltiSnips/  # Custom snippets
```

---

## ⚙️ Requirements & Setup

### Required

- **Neovim** >= 0.10.0 (0.11+ recommended)
- **Git** - For plugin management
- **Python 3** - For Neovim's Python provider and some plugins (optional)

### Optional but Recommended

- **Clang/LLVM** - clangd language server for C/C++ (optional)
- **ripgrep** - Fast search alternative to ag
- **the_silver_searcher** - Fast grep alternative
- **universal-ctags** - Better tag generation
- **fzf** - Fuzzy finder

```bash
# macOS optional tools
brew install ripgrep
brew install the_silver_searcher
brew install universal-ctags
brew install fzf
```

### LSP Setup

```bash
Install language servers for the languages you use (examples: `clangd`,
`pyright`, `gopls`, `typescript-language-server`). Neovim will auto-start them
when available on your PATH.
```

Diagnostics are configured to show only ERROR virtual text and keep the sign
column empty by default.

---

## 🛠️ Customization

### Using private.lua (Recommended!)

The `lua/config/private.lua` file is **never overwritten** on updates and should
return a list of optional plugins. For keymaps/settings/autocmds, use
`lua/config/private_config.lua`.

#### Add Optional Plugins

```lua
local optional_plugins = {
  { 'wakatime/vim-wakatime' },
  { 'tpope/vim-eunuch' },
  { 'numToStr/Comment.nvim' },
}

return optional_plugins
```

#### Add Custom Keymaps (private_config.lua)

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map('n', '<leader>x', ':MyCommand<CR>', opts)
```

#### Add Custom Settings (private_config.lua)

```lua
local opt = vim.opt

opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
```

#### Add Custom Autocommands (private_config.lua)

```lua
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local my_group = augroup('MyCustomGroup', { clear = true })

autocmd('BufWritePre', {
  group = my_group,
  pattern = '*.py',
  command = 'Autoformat',
})
```

### Edit Configuration Files

- **Keymaps**: `lua/config/keymaps.lua`
- **Settings**: `lua/config/settings.lua`
- **Plugins**: `lua/plugins/init.lua`
- **Theme**: `lua/config/theme.lua`
- **Optional plugins**: `lua/config/private.lua`
- **Personal configs**: `lua/config/private_config.lua`

### Change Leader Key

Edit `init.lua`:
```lua
vim.g.mapleader = ';'  -- Change from ',' to ';'
```

---

## 📦 Plugin Management

### In Neovim

```vim
:Lazy                  " Open plugin manager UI
:Lazy sync             " Update all plugins
:Lazy update           " Check for updates
:Lazy install          " Install missing plugins
:Lazy show <plugin>    " Show plugin details
:Lazy clean            " Clean unused plugins
```

### From Command Line

```bash
nvim --headless "+Lazy! sync" +qa
```

---

## 📝 Built-in Snippets

All UltiSnips from original m-vim are included!

### Snippet Triggers

In insert mode:
- Type snippet name and press `<Tab>` to expand
- `<Tab>` - Jump to next placeholder
- `<S-Tab>` - Jump to previous placeholder
- `,us` - Edit snippet definitions

### Included Snippets

| File | Contains |
|------|----------|
| **all.snippets** | Global: date, time, templates, blog templates |
| **python.snippets** | Imports, functions, classes, decorators |
| **js.snippets** | console.log, React, Bootstrap CDNs |
| **c.snippets** | Loops, functions, includes, headers |
| **cpp.snippets** | Algorithms (KMP, LCS, Fibonacci), STL containers, ACM snippets |
| **go.snippets** | Package, functions, error handling |
| **php.snippets** | Loops, functions, utilities |
| **snippets.snippets** | UltiSnips meta-snippets |

---

## 🆘 Common Troubleshooting

### Plugins not loading
```vim
:Lazy              " Check plugin status
:checkhealth       " System health check
:Lazy sync         " Resync all plugins
```

### LSP not working
```vim
:LspInfo                  " Show active language servers
:checkhealth              " System health check
```

### Snippets not expanding
- Check `:UltiSnipsEdit` works
- Verify `<Tab>` not mapped elsewhere
- Check `lua/config/plugins/ultisnips.lua`

### Performance issues
```vim
:Lazy                       " Disable heavy plugins
nvim --startuptime log.txt  " Profile startup time
:profile start log.txt      " Profile runtime
```

---

## 📚 Useful Commands

```vim
:checkhealth                " System health & diagnostics
:Lazy                       " Plugin manager UI
:Lazy sync                  " Sync all plugins
:LspInfo                   " Show active language servers
:lua vim.diagnostic.open_float() " Show diagnostics
:UltiSnipsEdit              " Edit snippet definitions
:TagbarToggle               " Toggle code outline
:NERDTreeToggle             " Toggle file tree
:MarkdownPreview            " Preview markdown
:Autoformat                 " Format current file
:set number!                " Toggle line numbers
:set wrap!                  " Toggle line wrapping
:set relativenumber!        " Toggle relative numbers
:colorscheme <name>         " Change colorscheme
:help lua                   " Lua documentation
:help nvim                  " Neovim manual
```

---

## 🎯 Quick Tips

1. **Record macros**: `qa...q` to record to `a`, then `@a` to replay
2. **Sort lines**: `:%!sort` or visual select and `!sort`
3. **Change colorscheme**: `:colorscheme everforest` (or gruvbox, solarized8, etc)
4. **Edit snippets**: `,us` (with trailing space for function snippets)
5. **Show help**: `:help index` for all commands
6. **Navigate splits**: `<C-h/j/k/l>`
7. **Search centered**: Use `/` to search - results auto-centered
8. **EasyMotion**: `,,` + direction for quick jumps
9. **Build/Run**: `,run` or `<F5>` for supported languages
10. **Sudo save**: Type `:w!!` in command mode

---

## 🔑 Configuration Files Reference

| File | Purpose |
|------|---------|
| `init.lua` | Main entry point, loads all modules |
| `lua/config/settings.lua` | Vim options (tabs, encoding, colors, etc) |
| `lua/config/keymaps.lua` | All keyboard shortcuts |
| `lua/config/theme.lua` | Colorscheme & UI settings |
| `lua/config/autocmds.lua` | Auto-commands for file types & events |
| `lua/config/private.lua` | Optional plugin list (never overwritten!) |
| `lua/config/private_config.lua` | Personal keymaps/settings/autocmds |
| `lua/plugins/init.lua` | List of 40+ plugins |
| `lua/config/plugins/*.lua` | Individual plugin configurations |

---

## 📖 Learning Resources

- [Neovim Documentation](https://neovim.io/doc/)
- [lazy.nvim Guide](https://github.com/folke/lazy.nvim)
- [Vim Cheat Sheet](https://vim.rtorr.com/)
- [Neovim Tips & FAQ](https://github.com/neovim/neovim/wiki/FAQ)

---

## 🆘 Getting Help

```vim
:checkhealth           " System health check
:Lazy                  " Plugin manager UI
:help lua              " Lua documentation
:help nvim             " Neovim manual
:LspInfo               " LSP debugging
:Lazy show <plugin>    " Show plugin info
```

---

## 📋 Default Settings Overview

- **Tabs**: 2 spaces (expandtab, smarttab)
- **Encoding**: UTF-8
- **Line numbers**: Enabled by default
- **Search**: Case-insensitive (with smartcase)
- **Mouse**: Disabled
- **Folding**: Indent-based with level 99
- **Backup**: Disabled (no swap/backup files)
- **Auto-read**: Files reloaded when changed externally
- **Color column**: 120 characters
- **Scroll offset**: 15 lines (keep cursor centered)

---

## 🚀 Advanced Usage

### Adding New Plugins

1. Edit `lua/plugins/init.lua` or `lua/config/private.lua`
2. Add plugin entry:
   ```lua
   { 'author/plugin-name' }
   ```
3. Save and restart Neovim
4. Plugins auto-install via lazy.nvim

### Creating Plugin Config

1. Create `lua/config/plugins/myplugin.lua`
2. In `init.lua`, add config line:
   ```lua
   {
     'author/plugin-name',
     config = function()
       require('config.plugins.myplugin')
     end,
   }
   ```

### Custom Snippets

1. Edit `~/.config/nvim/UltiSnips/python.snippets` (for example)
2. Use `:UltiSnipsEdit` to open in editor
3. Format: `snippet trigger "description" b ... endsnippet`

---

## 📞 Support

- Check `README.md` for detailed documentation
- See `MIGRATION.md` if migrating from m-vim
- Run `:checkhealth` for diagnostics
- Use `:Lazy` for plugin manager help

---

**Ported from m-vim to Modern Neovim**  
**Configuration: D0n9X1n (original) → Neovim Lua port**

Enjoy your Neovim! 🎉
