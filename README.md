# Neovim Configuration

A modern Neovim configuration ported from the original [m-vim](https://github.com/D0n9X1n/m-vim) setup.
Written in Lua, managed by [lazy.nvim](https://github.com/folke/lazy.nvim).

> **For AI agents**: See [`QUICKREF.md`](QUICKREF.md) for a machine-readable technical reference.

## Highlights

- **Lua-native** — fast startup, clean structure
- **lazy.nvim** plugin manager with auto-bootstrap
- **LSP + Treesitter** — smart completion, highlighting, and diagnostics out of the box
- **Telescope** — fuzzy file search, live grep, buffer switching
- **Neo-tree** — file explorer sidebar
- **UltiSnips** — bundled snippets for Python, JS, C/C++, Go, PHP
- **Private overrides** — `private.lua` for personal plugins, never touched by updates

## Requirements

- **Neovim** ≥ 0.10.0 (0.11+ recommended)
- **Git**
- A [Nerd Font](https://www.nerdfonts.com/) for icons

### Optional Tools

```bash
brew install ripgrep the_silver_searcher universal-ctags fzf
npm install -g @olrtg/emmet-language-server   # for HTML/CSS Emmet
```

Install language servers for the languages you use (e.g. `pyright`, `gopls`, `clangd`, `lua-language-server`).

## Installation

```bash
cd /path/to/nvim-config
./install.sh
```

The installer will:
1. Back up your existing `~/.config/nvim`
2. Symlink this config into place
3. Create `private.lua` if it doesn't exist
4. Install optional tools via Homebrew

On first launch, lazy.nvim auto-installs all plugins.

### Manual

```bash
git clone git@github.com:D0n9X1n/nvim-config.git ~/.config/nvim
```

## Structure

```
init.lua                    Entry point
lua/
  config/
    settings.lua            Editor settings (tabs, search, display)
    keymaps.lua             All key bindings
    autocmds.lua            Auto-commands
    theme.lua               Colorscheme & highlights
    private.lua             Your optional plugins (gitignored)
    private_config.lua      Your personal settings (gitignored)
    plugins/                Per-plugin configuration files
  plugins/
    init.lua                Plugin specifications for lazy.nvim
UltiSnips/                  Custom snippet files
```

## Key Bindings

Leader key: **`,`** (comma)

### Essentials

| Key | Action |
|-----|--------|
| `;` | Enter command mode (instead of `:`) |
| `kj` | Escape (insert mode) |
| `H` / `L` | Line start / end |
| `Y` | Yank to end of line |
| `U` | Redo |

### File Navigation

| Key | Action |
|-----|--------|
| `,n` | Toggle file tree (Neo-tree) |
| `,p` | Find files (Telescope) |
| `,f` | Live grep (Telescope) |
| `,b` | Switch buffers (Telescope) |
| `,s` | Search with Ag |
| `\` | Search word under cursor (CtrlSF) |

### Code

| Key | Action |
|-----|--------|
| `,jd` | Go to definition |
| `,gd` | Go to declaration |
| `,ee` | Show diagnostics |
| `<F5>` / `,run` | Quick run |
| `<F3>` / `,af` | Autoformat |
| `<F9>` | Toggle Tagbar |

### Completion & Snippets

| Key | Action |
|-----|--------|
| `<C-j>` / `<C-k>` | Navigate completion menu |
| `<C-Space>` | Trigger completion |
| `<CR>` | Confirm selection |
| `<Tab>` | Expand snippet / jump forward |
| `<S-Tab>` | Jump to previous placeholder |

### Buffers & Windows

| Key | Action |
|-----|--------|
| `[b` / `]b` | Previous / next buffer |
| `,q` | Close buffer (smart) |
| `<C-h/j/k/l>` | Navigate splits |
| `<C-t>` | New tab |

### EasyMotion

| Key | Action |
|-----|--------|
| `,,h/j/k/l` | Directional motion |
| `,,.` | Repeat last motion |

### Display Toggles

| Key | Action |
|-----|--------|
| `,bg` | Dark / light background |
| `,ln` / `<F10>` | Line numbers |
| `,rln` / `<F6>` | Relative numbers |
| `,wr` / `<F4>` | Word wrap |
| `<F8>` / `,il` | Indent guides |
| `<F12>` / `,git` | GitGutter |

### Git

| Key | Action |
|-----|--------|
| `,g` | Quick add, commit, pull & push |
| `<F12>` | Toggle GitGutter |

## Theme

Default: **Gruvbox** (dark, hard contrast). Change in `lua/config/theme.lua`.

Available: `gruvbox`, `solarized8`, `everforest`, `base16-*`, `ayu`.

## Customization

### Personal plugins — `private.lua`

This file is gitignored and never overwritten. It returns a table of plugin specs merged into lazy.nvim:

```lua
return {
  { 'wakatime/vim-wakatime' },
  { 'mbbill/undotree' },
}
```

### Personal settings — `private_config.lua`

Also gitignored. Add keymaps, settings, or autocommands here:

```lua
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
```

## Plugin Management

```vim
:Lazy              " Open plugin manager UI
:Lazy sync         " Install/update/clean plugins
```

Add plugins in `lua/plugins/init.lua`. If they need config, create a file in `lua/config/plugins/`.

## Snippets

Built-in snippets for: **all** (global), **Python**, **JavaScript**, **C**, **C++**, **Go**, **PHP**.

Edit snippets with `,us` or `:UltiSnipsEdit`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Plugins not loading | `:Lazy sync`, then `:checkhealth` |
| LSP not working | `:LspInfo` — ensure the language server binary is installed |
| Snippets not expanding | Check `:UltiSnipsEdit`, verify `<Tab>` isn't remapped |
| Slow startup | `nvim --startuptime startup.log` to profile |

## Updating

```bash
cd ~/.config/nvim && git pull
```

Then `:Lazy sync` inside Neovim.

## Credits

- Original Vim config: [D0n9X1n/m-vim](https://github.com/D0n9X1n/m-vim)
- Plugin manager: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

## License

MIT
