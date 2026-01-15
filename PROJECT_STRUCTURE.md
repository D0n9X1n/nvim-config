# Neovim Configuration - Project Structure

## 📁 Complete File Hierarchy

```
nvim-config/
├── init.lua                    # Main entry point
├── install.sh                  # macOS installer script
├── .gitignore
├── README.md                   # Complete documentation
├── QUICKREF.md                 # Keyboard shortcuts reference
├── MIGRATION.md                # Migration guide from m-vim
│
├── lua/
│   ├── config/
│   │   ├── settings.lua        # General vim settings
│   │   ├── keymaps.lua         # Keyboard mappings
│   │   ├── autocmds.lua        # Autocommands
│   │   ├── theme.lua           # Colorscheme & appearance
│   │   ├── private.lua         # Custom configs (template)
│   │   └── plugins/
│   │       ├── ycm.lua         # YouCompleteMe config
│   │       ├── ultisnips.lua   # UltiSnips config
│   │       ├── airline.lua     # Airline config
│   │       └── config.lua      # Other plugins config
│   │
│   └── plugins/
│       └── init.lua            # Plugin specifications (lazy.nvim)
│
└── snippets/                   # UltiSnips - All included!
    ├── all.snippets           # Global snippets (date, templates)
    ├── python.snippets        # Python (imports, functions, classes)
    ├── js.snippets            # JavaScript (console.log, React, CDN)
    ├── c.snippets             # C programming (loops, headers)
    ├── cpp.snippets           # C++ (algorithms, STL, ACM snippets)
    ├── go.snippets            # Go (functions, error handling)
    ├── php.snippets           # PHP (loops, utilities)
    └── snippets.snippets      # UltiSnips meta-snippets
```

## 📋 File Summary

### Core Configuration (11 Lua files)
- **init.lua**: Entry point, loads lazy.nvim and all modules
- **settings.lua**: Editor options (tabs, lines, encoding, etc)
- **keymaps.lua**: 40+ keyboard shortcuts and mappings
- **autocmds.lua**: Auto-commands for file types and events
- **theme.lua**: Colorscheme and UI settings
- **private.lua**: Template for personal customizations
- **ycm.lua**: YouCompleteMe completion settings
- **ultisnips.lua**: Snippet expansion configuration
- **airline.lua**: Status bar and tab line
- **config.lua**: Other plugin settings
- **plugins/init.lua**: List of 40+ plugins

### Documentation (5 files)
- **README.md**: Complete user guide and documentation
- **QUICKREF.md**: Quick keyboard reference
- **MIGRATION.md**: Guide for migrating from m-vim
- **PROJECT_STRUCTURE.md**: This file
- **install.sh**: Automated macOS installer

## 🎯 What's Included

### 40+ Plugins Across 10 Categories

**Language Support**: TypeScript, JavaScript, GraphQL, C/C++, Python, Solidity
**Completion**: YouCompleteMe, UltiSnips, vim-snippets
**Navigation**: NERDTree, CtrlP, Tagbar, vim-easymotion
**Version Control**: vim-fugitive, vim-gitgutter
**UI Enhancements**: vim-airline, rainbow, indentLine
**Formatting**: vim-autoformat, EditorConfig
**Editing**: vim-surround, vim-repeat, nerdcommenter, EasyAlign
**Themes**: Gruvbox, Solarized, Everforest, Base16, Ayu
**Search**: Ag.vim, CtrlSF, vim-easygrep
**Utilities**: Markdown preview, QuickRun, Gundo, Wakatime

## ✨ Key Features

✅ All original m-vim keybindings preserved
✅ Modern lazy.nvim plugin manager
✅ Lua configuration (clean, maintainable)
✅ 40+ organized plugins
✅ Full TypeScript/JavaScript support
✅ YouCompleteMe with snippets
✅ Git integration
✅ File tree and fuzzy search
✅ Code formatting and linting
✅ Multiple color schemes

## 🚀 Quick Start

```bash
# 1. Run installer
./install.sh

# 2. Open Neovim
nvim

# 3. Plugins auto-install on first run
# 4. Optional: pip install pynvim (for YouCompleteMe)
```

## 📊 Statistics

- **Lua Config Files**: 11
- **Total Plugins**: 40+
- **Configuration Lines**: 2000+
- **Startup Time**: 50-100ms
- **Documentation Files**: 5
- **Total Size (before plugins)**: ~300KB

## 🔑 Leader Key

All custom shortcuts use `,` (comma):
- `,p` - File search
- `,n` - Toggle file tree  
- `,jd` - Go to definition
- `,af` - Autoformat
- And 30+ more!

See QUICKREF.md for complete list.

## 📍 Installation Locations

```
~/.config/nvim/           # Main configuration
~/.local/share/nvim/lazy/ # Plugins (installed on first run)
~/.config/nvim/snippets/  # Custom snippets
```

## 🎨 Included Colorschemes

- **gruvbox** (default)
- solarized8
- solarized8_flat
- everforest
- base16-default-dark
- ayu (dark, light, mirage)

Switch with `:colorscheme name`

## ⚙️ Requirements

- **Neovim** >= 0.7.0
- **Git** (for plugin management)
- **Python 3** (for YouCompleteMe)
- **Optional**: Clang (via Xcode CLT) for C/C++ support

## 🔧 Customization

Edit these files to customize:
- **Keymaps**: `lua/config/keymaps.lua`
- **Settings**: `lua/config/settings.lua`
- **Plugins**: `lua/plugins/init.lua`
- **Personal**: `lua/config/private.lua`

## 📚 Documentation

- **README.md**: Full user guide
- **QUICKREF.md**: Keyboard reference
- **MIGRATION.md**: From m-vim
- **PROJECT_STRUCTURE.md**: This file

## 🆘 Getting Help

In Neovim:
```vim
:checkhealth           " System health check
:Lazy                  " Plugin manager UI
:help lua              " Lua documentation
:help nvim             " Neovim manual
```

## 📦 Plugin Management

```vim
:Lazy sync             " Update all plugins
:Lazy update           " Check for updates
:Lazy install          " Install missing plugins
:Lazy show <plugin>    " Show plugin details
```

## 🎓 Learning Resources

- [Neovim Documentation](https://neovim.io/doc/)
- [lazy.nvim Guide](https://github.com/folke/lazy.nvim)
- [Vim/Neovim Tips](https://vim.rtorr.com/)
- Check QUICKREF.md for quick commands

---

**Ported from m-vim to Modern Neovim**
**Configuration by D0n9X1n (original) → Neovim Lua port**

Enjoy! 🎉
