# Neovim Configuration

[![Latest Release](https://img.shields.io/github/v/release/D0n9X1n/nvim-config?style=flat-square&logo=github&label=release)](https://github.com/D0n9X1n/nvim-config/releases/latest)
[![Neovim](https://img.shields.io/badge/Neovim-%E2%89%A50.12-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/config-Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://github.com/D0n9X1n/nvim-config/tree/main/lua)
[![License](https://img.shields.io/github/license/D0n9X1n/nvim-config?style=flat-square&label=license)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/D0n9X1n/nvim-config?style=flat-square&logo=git&logoColor=white)](https://github.com/D0n9X1n/nvim-config/commits/main)

A modern Neovim configuration ported from the original [m-vim](https://github.com/D0n9X1n/m-vim.vimrc) setup.
Written in Lua, managed by [lazy.nvim](https://github.com/folke/lazy.nvim).

> **For Claude Code**: See [`CLAUDE.md`](CLAUDE.md) for repository operations and architecture.

## Highlights

- **Lua-native** — fast startup, clean structure
- **lazy.nvim** plugin manager with auto-bootstrap
- **LSP + Treesitter** — smart completion, highlighting, and diagnostics out of the box
- **Telescope** — fuzzy file search, live grep, buffer switching
- **Neo-tree** — file explorer sidebar
- **UltiSnips** — bundled snippets for Python, JS, C/C++, Go, PHP
- **Private overrides** — `private.lua` for personal plugins, never touched by updates

## Requirements

- **Neovim** ≥ 0.12.0 (required starting with v1.0.0)
- **Git**
- A [Nerd Font](https://www.nerdfonts.com/) for icons

### Optional Tools

```bash
brew install ripgrep the_silver_searcher universal-ctags fzf
npm install -g @olrtg/emmet-language-server   # for HTML/CSS Emmet
```

Install language servers for the languages you use (e.g. `pyright`, `gopls`, `clangd`, `lua-language-server`). UltiSnips and Gundo require a working Neovim Python 3 provider; check it with `:checkhealth vim.provider`.

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

Use `./install.sh --no-deps` to skip Homebrew installations. The installer honors `XDG_CONFIG_HOME`, replaces managed files only after backing up the existing configuration, and preserves both personal extension files.

On first launch, lazy.nvim auto-installs plugins. Treesitter loads eagerly using its current API; language parsers are installed explicitly, not downloaded when opening files:

```vim
:TSInstall lua python javascript typescript
```

Parser installation requires a C compiler and `tree-sitter` CLI 0.26.1+ from your package manager (not npm), plus `tar` and `curl`. Files without a parser remain editable using their normal syntax and indentation.

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
| `,q` | Close buffer; refuse unsaved changes; leave an empty buffer after the last file |
| `<C-h/j/k/l>` | Navigate splits |
| `<C-t>` | New tab |
| `,tt` | Return to the previous tab |
| `,t` | Open a terminal split |

`,t` waits for the mapping timeout because `,tt` shares its prefix. `*` searches backward and `#` searches forward; both center the result.

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
| `<F8>` / `,il` | Indent guides (off by default; toggle to enable) |
| `<F12>` / `,git` | GitGutter |

### Git

| Key | Action |
|-----|--------|
| `,gs` | Open Git status (Fugitive) |
| `<F12>` | Toggle GitGutter |

The former `,g` automatic commit/push and `,w` / `w!!` sudo-write mappings are removed. Commit and push explicitly; use an external privileged editing workflow when needed.

## Theme

Default: **Apollo** (warm, high-contrast dark). Change in `lua/config/theme.lua`.

Available: `apollo`, `gruvbox`, `solarized8`, `everforest`, `base16-*`, `ayu`.

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
git -C /path/to/nvim-config pull --ff-only
/path/to/nvim-config/install.sh --no-deps
```

Use the original checkout path, not the installer-created `~/.config/nvim` directory (which is not a Git checkout). For a manual clone directly at `~/.config/nvim`, that is your checkout path. Then run `:Lazy sync` inside Neovim.

## Validation

```bash
bash scripts/smoke.sh
```

Requires Python 3 (including Neovim's Python provider), Neovim 0.12+, and the plugins already installed. Tests copy tracked public runtime files into a temporary config, omit private overrides, isolate data/state/cache and lockfiles, disable ShaDa, and refuse plugin/parser downloads. The matrix includes installer fixtures, harness failure controls, buffer/tab safety, Treesitter highlighting/indentation, and existing directory-startup/diagnostic checks. Missing test prerequisites fail explicitly.

## Credits

- Original Vim config: [D0n9X1n/m-vim.vimrc](https://github.com/D0n9X1n/m-vim.vimrc)
- Plugin manager: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

## License

MIT
