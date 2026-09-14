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

### macOS / Linux

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

### Windows / PowerShell

Use native Windows Neovim 0.12+ and Git on `PATH`. PowerShell 7 is recommended; the installer also supports Windows PowerShell 5.1. Bash, WSL, administrator rights, and Developer Mode are not required.

```powershell
git clone https://github.com/D0n9X1n/nvim-config.git
Set-Location nvim-config
.\install.ps1
nvim
```

The PowerShell installer:

- Queries Neovim's `stdpath('config')` (normally `$env:LOCALAPPDATA\nvim`), honoring `XDG_CONFIG_HOME` and `NVIM_APPNAME`.
- Copies public runtime files instead of creating symlinks. Rerun it after updating the checkout.
- Preserves `lua/config/private.lua`, `lua/config/private_config.lua`, and unrelated existing files; never imports private files from the checkout.
- Stages the installation before replacing the old config and keeps an independent sibling `*.backup.*` directory. An unchanged rerun creates no additional backup. If activation fails, it attempts to restore the old config.
- Refuses junctions/symlinks and overlapping source/destination paths rather than modifying linked files. Migrate those layouts manually first.
- Reports missing optional tools without installing packages. `-NoDeps` skips that report. It does not change PowerShell's execution policy; if local policy blocks scripts, use your organization's approved procedure.

To recover a backup, close Neovim, move the current config aside, and move the printed backup directory back to the original config path. Do not delete the current config before checking whether it contains newer private edits.

Install the optional tools you need using your preferred Windows package manager: `rg` (Telescope live grep), `ag`, `fzf`, Universal Ctags, Python plus `pynvim`, and language servers. Check the Python provider with `:checkhealth vim.provider`. Treesitter parser installation additionally needs a Windows C compiler, `tree-sitter` CLI 0.26.1+, `tar`, and `curl`; it remains an explicit `:TSInstall` step.

On Windows, Neovim selects `pwsh` when available, otherwise `powershell`, including for `,t` and `:!` commands. Personal shell overrides can go in `private_config.lua`. Markdown preview uses native PowerShell rather than Bash to download its version-matched upstream Windows executable during plugin setup; download and extraction failures stop the build.

**Known limits:** QuickRun's bundled C/C++ commands use Unix executable names; configure native commands through `g:quickrun_known_file_types` in your private overrides. Its multi-command defaults use `&&`, which Windows PowerShell 5.1 does not support. This is not a guarantee that every legacy plugin's external command works unchanged on Windows.

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
| `,s` | Load Ag, then open editable search input (safe on first use with Wilder) |
| `\` | Search word under cursor (CtrlSF) |

Ag results use an unlisted quickfix utility window, not an editor tab. The buffer panel and bottom statusline keep the real editor context; Enter opens a result in the editor and `q` closes the results window.

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

Bufferline uses `MOSconfig/bufferline.nvim` pinned to `v4.10.1`, with up to three wrapped rows above the editor area only. Neo-tree stays full-height on the left and remains available with `,n`; no repeated Explorer placeholder is needed.

Opening a named file removes unused, empty, unmodified `[No Name]` buffers. Unnamed buffers containing text, unsaved changes, or displayed in another window are preserved.

Adjust `tab_size` (currently `16`) in `lua/config/plugins/bufferline.lua` to change buffer-tab width. `enforce_regular_tabs = true` and `truncate_names = true` keep tabs bounded and trim long names with an ellipsis.

- Enter the header with `<C-k>` (or `<C-w>k`) from the editing window below it. The normal-mode cursor is hidden there; the tab highlight indicates selection. Leaving restores your editor cursor.
- Use `h`/`l` to move between buffer entries and `j`/`k` to move between rows, including overflow. These keys choose a candidate without switching your file.
- Press Enter to open the candidate in the editing window, or Escape to return without selecting. `:q` while in the header closes the header and returns to the editor.
- The active file has a full blue tab background; the keyboard candidate uses a distinct full-tab search highlight. Tabs use Bufferline’s `slope` style by default. One bottom statusline follows the editing file even while the header is focused; the scratch header has no separate `[No Name]` banner. Close buttons are hidden, but modified-file indicators remain.
- Press `x` in the header to close the highlighted candidate. Open files use the same smart-close action as `,q`, preserving splits across tabpages; hidden files are removed without switching the editor. Unsaved files and files in locked windows are refused. Selection moves to a surviving neighbor after closure and stays in the header.
- Scroll over the header or click the Nerd Font chevrons to browse overflow; click a buffer to open it directly. Terminal mouse reporting must be enabled; user mouse mappings can consume those events.

Multi-row uses an extra header split. `multiline.enabled` is the only renderer switch: closing splits, `:only`, or temporarily insufficient space never enables native tabs. The header is rebuilt when the layout permits. Before saving a session, explicitly disable multiline to avoid serializing its scratch window. To select native rendering, set `multiline.enabled = false` in `lua/config/plugins/bufferline.lua` and restart.

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

On Windows, run from your original checkout:

```powershell
git pull --ff-only
.\install.ps1 -NoDeps
```

Use the original checkout path, not the installer-created `~/.config/nvim` directory (which is not a Git checkout). For a manual clone directly at `~/.config/nvim`, that is your checkout path. Then run `:Lazy sync` inside Neovim.

## Validation

```bash
bash scripts/smoke.sh
```

Requires Python 3 (including Neovim's Python provider), Neovim 0.12+, and the plugins already installed. Tests copy tracked public runtime files into a temporary config, omit private overrides, isolate data/state/cache and lockfiles, disable ShaDa, and refuse plugin/parser downloads. The matrix includes installer fixtures, harness failure controls, buffer/tab safety, Treesitter highlighting/indentation, and existing directory-startup/diagnostic checks. Missing test prerequisites fail explicitly.

### Windows pipeline

`.github/workflows/windows.yml` runs on pull requests, pushes to `main`, and manual dispatch. Separate `windows-2022` jobs use Windows PowerShell 5.1 and PowerShell 7, with Git Bash directories excluded from the test `PATH`. They download checksum-verified Neovim 0.12.5, install the Python provider, run disposable installer fixtures, real PowerShell commands, and an attached-UI terminal input/output test, then install plugins into isolated CI directories and validate configuration startup plus the Markdown preview Windows binary. Actions are commit-pinned, credentials are not persisted, and workflow permissions are read-only.

Run the non-network regression suite locally on Windows:

```powershell
powershell.exe -NoProfile -File .\scripts\windows-regression.ps1
pwsh -NoProfile -File .\scripts\windows-regression.ps1
```

It requires Neovim and Git but does not load your personal configuration, install plugins, or call a package manager. The CI-only `-Integration` mode deliberately loads the selected installed config; do not use it against private/live configuration. Plugin installation in CI requires network access. Browser rendering and every optional language tool are not covered; manually verify `,t`, `:!Write-Output hi`, Telescope searches, and Markdown preview on your machine.

The pipeline must pass on Windows before native support is considered verified. Local macOS Lua branch tests and workflow linting are not substitutes for a hosted Windows run.

## Credits

- Original Vim config: [D0n9X1n/m-vim.vimrc](https://github.com/D0n9X1n/m-vim.vimrc)
- Plugin manager: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

## License

MIT
