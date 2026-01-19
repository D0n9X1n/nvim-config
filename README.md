# Neovim Configuration

A modern Neovim configuration ported from the original m-vim Vim configuration by D0n9X1n.

This configuration uses **lazy.nvim** as the plugin manager and is written in Lua for better performance and maintainability.

## Features

- **Plugin Manager**: lazy.nvim
- **Language Support**: Treesitter-based highlighting + LSP (TypeScript/JavaScript, GraphQL, Solidity, Go, Python, C/C++)
- **Completion**: nvim-cmp with built-in LSP and UltiSnips
- **File Navigation/Search**: neo-tree, Telescope, CtrlSF, Ag, bufferline, buffer manager
- **Version Control**: vim-fugitive + GitGutter
- **UI Enhancements**: lualine, bufferline, wilder cmdline, rainbow parentheses, indent guides
- **Code Quality**: Autoformat (vim-autoformat), EditorConfig
- **Web/Markdown**: nvim-colorizer, nvim-emmet, markdown.nvim, markdown-preview
- **Colorschemes**: Gruvbox (default), Solarized, Everforest, Base16, and more

## Requirements

- **Neovim**: >= 0.10.0 (0.11+ recommended)
- **Git**: For plugin management
- **Python3**: For Neovim's Python provider and some plugins (optional)
- **Clang/LLVM**: For the clangd language server (optional)

### Optional Tools

For enhanced functionality (Telescope, search, tags), install these tools:

```bash
brew install ripgrep          # Fast search (alternative to ag)
brew install the_silver_searcher  # Silver searcher
brew install universal-ctags  # Tag generation
brew install fzf              # Fuzzy finder
```

Emmet support requires `emmet-language-server`:

```bash
npm install -g @olrtg/emmet-language-server
```

## Installation

### Quick Install

```bash
cd /path/to/nvim-config
./install.sh
```

The installer will:
1. Backup your existing Neovim config
2. Symlink this configuration into `~/.config/nvim` (including all snippets)
3. Keep `lua/config/private.lua` local and create it if missing
4. Install optional dependencies via Homebrew

**Everything is included** - no need to copy snippets separately!
UltiSnips expects snippets under `UltiSnips/`, which this repo provides.
The configuration includes all UltiSnips from the original m-vim setup.

### Manual Installation

```bash
# Clone or copy the configuration
git clone <repo-url> ~/.config/nvim

# Or copy manually
cp -r nvim-config/* ~/.config/nvim/
```

On first run, Neovim will automatically:
1. Install lazy.nvim (plugin manager)
2. Download and install all plugins
3. Set up your environment

## Configuration Structure

```
nvim-config/
├── init.lua                 # Main entry point
├── lua/
│   ├── config/
│   │   ├── settings.lua     # General settings
│   │   ├── keymaps.lua      # Key bindings
│   │   ├── autocmds.lua     # Autocommands
│   │   ├── theme.lua        # Theme and appearance
│   │   ├── private.lua      # Optional plugins (local)
│   │   ├── private_config.lua # Personal keymaps/settings/autocmds
│   │   └── plugins/         # Plugin configurations
│   │       ├── lsp.lua
│   │       ├── cmp.lua
│   │       ├── ultisnips.lua
│   │       ├── lualine.lua
│   │       ├── bufferline.lua
│   │       ├── buffer_manager.lua
│   │       ├── telescope.lua
│   │       ├── neo-tree.lua
│   │       ├── typescript-tools.lua
│   │       ├── treesitter.lua
│   │       ├── colorizer.lua
│   │       ├── emmet.lua
│   │       ├── markdown.lua
│   │       ├── wilder.lua
│   │       └── config.lua
│   └── plugins/
│       └── init.lua         # Plugin specifications
└── UltiSnips/               # UltiSnips snippet directory
    ├── all.snippets
    ├── python.snippets
    ├── js.snippets
    ├── c.snippets
    ├── cpp.snippets
    ├── go.snippets
    ├── php.snippets
    └── snippets.snippets
```

## Built-in Snippets

This configuration includes **all UltiSnips** from the original m-vim setup, making it completely self-contained.
The snippet files live under `UltiSnips/` (UltiSnips format expects that directory name).

### Snippet Files Included

- **all.snippets** - Global snippets (date, time, templates, blog templates)
- **python.snippets** - Python-specific snippets (imports, functions, classes, decorators)
- **js.snippets** - JavaScript snippets (console.log, React, Bootstrap CDNs)
- **c.snippets** - C programming snippets (loops, functions, includes)
- **cpp.snippets** - C++ snippets with algorithms (KMP, LCS, Fibonacci, STL containers)
- **go.snippets** - Go programming snippets (package, functions, error handling)
- **php.snippets** - PHP snippets (loops, functions, utilities)

### Using Snippets

In insert mode:
- `<Tab>` - Expand a snippet (e.g., type `date` then press Tab)
- `<Tab>` - Jump to next placeholder
- `<S-Tab>` - Jump to previous placeholder
- `,us` - Edit snippet definitions (leader key)

## Key Bindings

### General

| Key | Action |
|-----|--------|
| `,` | Leader key |
| `;` | `:` (faster command mode) |
| `kj` | `<Esc>` (in insert mode) |
| `H` | Jump to line start |
| `L` | Jump to line end |

### Navigation

| Key | Action |
|-----|--------|
| `<C-h/j/k/l>` | Navigate splits |
| `[b` / `]b` | Previous/next buffer |
| `<Left>` / `<Right>` | Previous/next buffer |
| `<C-t>` | New tab |

### File Management

| Key | Action |
|-----|--------|
| `,n` | Toggle neo-tree |
| `,p` | Telescope file search |
| `,f` | Telescope live grep |
| `,b` | Telescope buffers |
| `,s` | Ag (search in files) |
| `\` | CtrlSF (search context) |

### Editing

| Key | Action |
|-----|--------|
| `,a` | EasyAlign |
| `,<space>` | Fix trailing whitespace |
| `,/` | Clear search highlight |
| `<F2>/<F3>` | Autoformat |
| `,af` | Autoformat |

### Navigation & Movement

| Key | Action |
|-----|--------|
| `,,h/j/k/l` | EasyMotion |
| `,,<space>` | Repeat last motion |

### Development

| Key | Action |
|-----|--------|
| `,jd` | Go to definition (LSP) |
| `,gd` | Go to declaration (LSP) |
| `,ee` | Show diagnostics (LSP) |
| `,t` / `,tt` | Open split terminal |
| `<F9>` | Toggle Tagbar |
| `,m` | Markdown preview |
| `,run` / `<F5>` | Quick run code |

### Git

| Key | Action |
|-----|--------|
| `,git` / `<F12>` | Toggle GitGutter |

### Display

| Key | Action |
|-----|--------|
| `,bg` | Toggle background (dark/light) |
| `,ln` / `<F10>` | Toggle line numbers |
| `,rln` / `<F6>` | Toggle relative numbers |
| `,wr` / `<F4>` | Toggle line wrap |
| `,syn` / `<F7>` | Toggle syntax highlighting |
| `,il` / `<F8>` | Toggle indent guides |

## Plugin Management

### Adding Plugins

Edit `lua/plugins/init.lua` and add your plugin:

```lua
{ 'plugin-author/plugin-name' }
```

Or with configuration:

```lua
{
  'plugin-author/plugin-name',
  config = function()
    require('config.plugins.my-plugin')
  end,
}
```

### Updating Plugins

In Neovim:
```vim
:Lazy sync
```

Or from command line:
```bash
nvim --headless "+Lazy! sync" +qa
```

### Removing Plugins

1. Remove the entry from `lua/plugins/init.lua`
2. Run `:Lazy sync` in Neovim

## Important Setup Notes

### LSP (nvim-lspconfig + nvim-cmp)

Install language servers for the languages you use (e.g. `clangd`, `pyright`,
`gopls`, `typescript-language-server`). Neovim will auto-start them when the
executables are available. TypeScript is additionally configured via
`pmizio/typescript-tools.nvim`. Diagnostics are configured to show only ERROR
virtual text and keep the sign column empty by default.

### Emmet

HTML/CSS Emmet is powered by `olrtg/nvim-emmet` and requires the
`emmet-language-server` binary on your PATH.

### UltiSnips

- Snippets are stored in `~/.config/nvim/UltiSnips`
- Default snippets come from honza/vim-snippets plugin
- Custom snippets go in the `UltiSnips/` directory
- Edit snippets with `,us`

### Snippets Directory

Create your custom snippets in `~/.config/nvim/UltiSnips/`:

```
UltiSnips/
├── python.snippets
├── javascript.snippets
└── all.snippets
```

## Theme Customization

Edit `lua/config/theme.lua` to change:

- **Colorscheme**: `vim.cmd('colorscheme gruvbox')`
- **Background**: `opt.background = 'dark'`
- **Font** (GUI): `opt.guifont = 'Font Name:h14'`

Available colorschemes:
- `gruvbox` (default)
- `solarized8`, `solarized8_flat`
- `everforest`
- `base16-default`
- `ayu`

## Customization Tips

### Change Leader Key

Edit `init.lua`:
```lua
vim.g.mapleader = ';'  -- Change from ',' to ';'
```

### Private Customizations (private.lua)

The `lua/config/private.lua` file is designed for your optional plugin list and
will **never be overwritten** on updates. For personal keymaps/settings, create
`lua/config/private_config.lua`.

#### Add Optional Plugins

Define optional plugins in `private.lua`:

```lua
local optional_plugins = {
  -- Wakatime - Time tracking for coding
  { 'wakatime/vim-wakatime' },
  
  -- Other optional plugins
  { 'tpope/vim-eunuch' },           -- Unix shell commands
  { 'numToStr/Comment.nvim' },      -- Better commenting
  { 'mbbill/undotree' },            -- Visual undo history
}

return optional_plugins
```

#### Add Custom Keymaps

In `private_config.lua`:
```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map('n', '<leader>x', ':MyCommand<CR>', opts)
```

#### Add Custom Settings

In `private_config.lua`:
```lua
local opt = vim.opt

opt.tabstop = 4
opt.shiftwidth = 4
```

#### Add Custom Autocommands

In `private_config.lua`:
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

**Note**: `private.lua` is your safe space for optional plugins - it's in
`.gitignore` and will never be touched by updates. Use `private_config.lua` for
personal settings, keymaps, and autocmds.

### Disable Plugins

In `lua/plugins/init.lua`, comment out or remove plugin entries:
```lua
-- { 'wakatime/vim-wakatime' },
```

For optional plugins, use `private.lua` instead (it won't be overwritten on updates).
For personal config, use `private_config.lua`.

### Add Custom Keymaps

Add to `lua/config/keymaps.lua`:
```lua
map('n', '<leader>x', ':MyCommand<CR>', opts)
```

### Add Custom Settings

Add to `lua/config/settings.lua`:
```lua
opt.myoption = value
```

## Troubleshooting

### Plugins not loading

1. Run `:Lazy` to see plugin status
2. Check for errors with `:checkhealth`
3. Try `:Lazy sync` to resync plugins

### LSP not working

1. Check `:LspInfo` to see attached servers
2. Ensure the language server binary is installed and on your PATH
3. Run `:checkhealth` for diagnostics

### Snippets not expanding

- Check `:UltiSnipsEdit` opens correctly
- Verify `<Tab>` is not mapped elsewhere
- Check `lua/config/plugins/ultisnips.lua` configuration

### Performance issues

1. Disable heavy plugins temporarily: `:Lazy`
2. Check startup time: `nvim --startuptime startup.log`
3. Profile with `:profile start profile.log` then `:q`

## Updating This Config

To get updates:

```bash
cd ~/.config/nvim
git pull
```

Then in Neovim:
```vim
:Lazy sync
```

## Uninstalling

```bash
rm -rf ~/.config/nvim
# Optionally restore backup if available
# mv ~/.config/nvim.backup.XXXXXXX_XXXXXX ~/.config/nvim
```

## Credits

- **Original**: D0n9X1n - m-vim configuration
- **Ported to Neovim**: Modern Lua configuration using lazy.nvim
- **Plugin Manager**: folke/lazy.nvim

## License

This configuration is provided as-is. Refer to individual plugin licenses.

## Additional Resources

- [Neovim Documentation](https://neovim.io/doc/)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [Vim Cheat Sheet](https://vim.rtorr.com/)
- [Neovim Tips](https://github.com/neovim/neovim/wiki/FAQ)

---

**Enjoy your Neovim experience!** 🚀
