# QUICKREF.md — AI/Agent Reference for nvim-config

> **Purpose**: Machine-readable reference for AI agents working on this Neovim configuration.
> For human-readable documentation, see `README.md`.

---

## 1. Project Identity

- **What**: Lua-based Neovim configuration, ported from the original m-vim (Vim) config by D0n9X1n.
- **Plugin manager**: lazy.nvim (auto-bootstrapped in `init.lua`).
- **Minimum Neovim**: 0.10.0 (0.11+ recommended). Uses `vim.lsp.config` + `vim.lsp.enable` API.
- **Target OS**: macOS (Homebrew assumed in `install.sh`), but config is cross-platform Lua.
- **Repo**: `git@github.com:D0n9X1n/nvim-config.git` (branch: `main`).
- **License**: MIT.

---

## 2. Deployment Model

The repo lives at `~/Public/nvim-config/`. The installer (`install.sh`) creates **symlinks** from `~/.config/nvim/` back into this repo:

| Symlinked target | Source in repo |
|---|---|
| `~/.config/nvim/init.lua` | `init.lua` |
| `~/.config/nvim/lua` | `lua/` |
| `~/.config/nvim/UltiSnips` | `UltiSnips/` |
| `~/.config/nvim/install.sh` | `install.sh` |
| `~/.config/nvim/README.md` | `README.md` |
| `~/.config/nvim/QUICKREF.md` | `QUICKREF.md` |
| `~/.config/nvim/LICENSE` | `LICENSE` |

**Not symlinked** (local to `~/.config/nvim/`):
- `lazy-lock.json` — lazy.nvim lockfile, machine-specific.

**Private files** (gitignored, never overwrite):
- `lua/config/private.lua` — optional plugin list (returns a Lua table merged into lazy spec).
- `lua/config/private_config.lua` — personal keymaps/settings/autocmds (loaded via `pcall` at end of `init.lua`).

Editing any file in `~/Public/nvim-config/` immediately affects the live Neovim config via symlinks.

---

## 3. File Map & Load Order

### Boot sequence (`init.lua`)
```
1. Set leader key: ","
2. require("config.settings")      -- vim options
3. require("config.keymaps")       -- all key mappings
4. require("config.autocmds")      -- autocommands
5. require("config.plugins.config") -- vim.g settings for vimscript plugins
6. Bootstrap lazy.nvim (clone if missing)
7. lazy.setup({ import = "plugins" } + private.lua plugins)
8. require("config.theme")         -- colorscheme + highlights
9. pcall(require, "config.private_config") -- optional personal overrides
```

### Full file tree
```
nvim-config/
├── init.lua                          # Entry point, boot sequence above
├── install.sh                        # macOS installer (symlinks + brew deps)
├── README.md                         # Human documentation
├── QUICKREF.md                       # This file (AI reference)
├── LICENSE                           # MIT
├── .gitignore                        # Ignores private.lua, lazy-lock.json, .DS_Store, etc.
├── lua/
│   ├── config/
│   │   ├── settings.lua              # vim.opt settings (tabs, search, display, encoding)
│   │   ├── keymaps.lua               # All key bindings (vim.keymap.set)
│   │   ├── autocmds.lua              # Autocommands (cursor restore, whitespace strip, filetype)
│   │   ├── theme.lua                 # Gruvbox dark, diagnostic highlights, cursor shapes
│   │   ├── private.lua               # [GITIGNORED] Optional plugins list
│   │   └── plugins/                  # Individual plugin configurations
│   │       ├── config.lua            # vim.g settings: NERDCommenter, CtrlSF, GitGutter, Tagbar,
│   │       │                         #   EasyMotion, QuickScope, MultiCursors, Rainbow, Autoformat
│   │       ├── lsp.lua               # LSP: diagnostics config, lspconfig for pyright/gopls/clangd/
│   │       │                         #   bashls/jsonls/yamlls/graphql/solidity_ls/lua_ls
│   │       │                         #   Uses setup_if_executable() — only enables if binary on PATH
│   │       ├── cmp.lua               # nvim-cmp: sources=[nvim_lsp, ultisnips, buffer, path],
│   │       │                         #   mappings: C-j/C-k (navigate), C-Space (complete), CR (confirm)
│   │       ├── treesitter.lua        # Treesitter: auto_install=true, highlight+indent enabled
│   │       ├── telescope.lua         # Telescope: ascending sort, top prompt, 90% width
│   │       ├── neo-tree.lua          # Neo-tree: left panel 32-wide, show dotfiles, follow current file,
│   │       │                         #   mappings: l/CR=open, h=close, space=toggle
│   │       ├── lualine.lua           # Lualine: auto theme, powerline separators, branch+diff+diagnostics
│   │       ├── bufferline.lua        # Bufferline: buffer mode, neo-tree offset, no close icons
│   │       ├── typescript-tools.lua  # typescript-tools.nvim: no inlay hints
│   │       ├── ultisnips.lua         # UltiSnips: Tab expand/forward, S-Tab backward
│   │       ├── wilder.lua            # Wilder: popup menu for :/?  with devicons+scrollbar
│   │       ├── colorizer.lua         # nvim-colorizer: all filetypes, no named colors
│   │       ├── emmet.lua             # nvim-emmet: stub :EmmetInstall command for legacy autocmds
│   │       └── markdown.lua          # markdown.nvim: default setup
│   └── plugins/
│       └── init.lua                  # Plugin specifications (lazy.nvim spec table)
└── UltiSnips/                        # Custom snippet files (UltiSnips format)
    ├── all.snippets                  # Global: date, time, templates, blog
    ├── python.snippets               # Python: imports, functions, classes, decorators
    ├── js.snippets                   # JavaScript: console.log, React, Bootstrap CDNs
    ├── c.snippets                    # C: loops, functions, includes
    ├── cpp.snippets                  # C++: algorithms (KMP, LCS, Fibonacci), STL containers
    ├── go.snippets                   # Go: package, functions, error handling
    ├── php.snippets                  # PHP: loops, functions, utilities
    ├── snippets.snippets             # Meta snippets
    └── README.md                     # Snippet documentation
```

---

## 4. Plugin Inventory

All plugins are specified in `lua/plugins/init.lua`. Config files are in `lua/config/plugins/`.

| Category | Plugin | Config file | Notes |
|---|---|---|---|
| **Syntax** | `nvim-treesitter/nvim-treesitter` | `treesitter.lua` | auto_install=true |
| **Syntax** | `leafgarland/typescript-vim` | — | vim syntax |
| **Syntax** | `pangloss/vim-javascript` | — | vim syntax |
| **Syntax** | `jparise/vim-graphql` | — | vim syntax |
| **Syntax** | `HerringtonDarkholme/yats.vim` | — | TS syntax |
| **Syntax** | `Quramy/tsuquyomi` | — | TS tooling |
| **Syntax** | `tomlion/vim-solidity` | — | Solidity syntax |
| **Formatter** | `gpanders/editorconfig.nvim` | — | .editorconfig support |
| **Formatter** | `Chiel92/vim-autoformat` | `config.lua` | `:Autoformat`, F3 |
| **Colorscheme** | `MOSconfig/vim-solarized8` | `theme.lua` | GUI fallback |
| **Colorscheme** | `MOSconfig/gruvbox` | `theme.lua` | Default (dark hard) |
| **Colorscheme** | `chriskempson/base16-vim` | — | |
| **Colorscheme** | `sainnhe/everforest` | — | |
| **Colorscheme** | `ayu-theme/ayu-vim` | — | |
| **HTML/CSS** | `NvChad/nvim-colorizer.lua` | `colorizer.lua` | All filetypes |
| **HTML/CSS** | `olrtg/nvim-emmet` | `emmet.lua` | Needs emmet-language-server |
| **Markdown** | `MeanderingProgrammer/markdown.nvim` | `markdown.lua` | ft=markdown |
| **Markdown** | `iamcco/markdown-preview.nvim` | — | `:MarkdownPreviewToggle` |
| **Tags/Nav** | `majutsushi/tagbar` | `config.lua` | F9, width=35 |
| **Tags/Nav** | `bronson/vim-trailing-whitespace` | — | `:FixWhitespace` |
| **Search** | `dkprice/vim-easygrep` | — | |
| **Search** | `rking/ag.vim` | — | `,s` |
| **Search** | `dyng/ctrlsf.vim` | `config.lua` | `\` searches word under cursor |
| **LSP** | `neovim/nvim-lspconfig` | `lsp.lua` | 10 servers, conditional enable |
| **LSP** | `pmizio/typescript-tools.nvim` | `typescript-tools.lua` | Dedicated TS server |
| **Completion** | `hrsh7th/nvim-cmp` | `cmp.lua` | LSP+snippets+buffer+path |
| **Completion** | `hrsh7th/cmp-nvim-lsp` | — | nvim-cmp source |
| **Completion** | `hrsh7th/cmp-buffer` | — | nvim-cmp source |
| **Completion** | `hrsh7th/cmp-path` | — | nvim-cmp source |
| **Completion** | `hrsh7th/cmp-cmdline` | — | nvim-cmp source |
| **Completion** | `quangnguyen30192/cmp-nvim-ultisnips` | — | nvim-cmp source |
| **Snippets** | `SirVer/ultisnips` | `ultisnips.lua` | Tab/S-Tab, custom UltiSnips/ dir |
| **Snippets** | `honza/vim-snippets` | — | Default snippet collection |
| **Editing** | `docunext/closetag.vim` | — | Auto-close HTML tags |
| **Editing** | `Raimondi/delimitMate` | — | Auto-close brackets/quotes |
| **Editing** | `junegunn/vim-easy-align` | — | `,a` in normal+visual |
| **Editing** | `scrooloose/nerdcommenter` | `config.lua` | Space delimiters, C/C++ block |
| **Editing** | `tpope/vim-repeat` | — | Dot-repeat for plugins |
| **Editing** | `tpope/vim-surround` | — | Surround motions |
| **Editing** | `luochen1990/rainbow` | `config.lua` | Rainbow parentheses, active=1 |
| **Editing** | `unblevable/quick-scope` | `config.lua` | Highlight f/F/t/T targets |
| **Editing** | `terryma/vim-multiple-cursors` | `config.lua` | C-d next, C-p prev, C-j skip |
| **Editing** | `folke/todo-comments.nvim` | — | TODO/FIXME highlights |
| **Movement** | `Lokaltog/vim-easymotion` | `config.lua` | `,,h/j/k/l/.` |
| **Telescope** | `nvim-telescope/telescope.nvim` | `telescope.lua` | `,p` files, `,f` grep, `,b` buffers |
| **File tree** | `nvim-neo-tree/neo-tree.nvim` | `neo-tree.lua` | `,n` toggle, left panel |
| **UI** | `nvim-lualine/lualine.nvim` | `lualine.lua` | Statusline, auto theme |
| **UI** | `akinsho/bufferline.nvim` | `bufferline.lua` | Buffer tabs |
| **UI** | `gelguy/wilder.nvim` | `wilder.lua` | Cmdline popup |
| **Git** | `tpope/vim-fugitive` | — | `:Git` commands |
| **Git** | `airblade/vim-gitgutter` | `config.lua` | F12/`,git`, disabled by default |
| **Misc** | `sjl/gundo.vim` | — | Undo tree |
| **Misc** | `MikeCoder/quickrun.vim` | — | F5/`,run` |

---

## 5. Key Settings (settings.lua)

| Setting | Value | Notes |
|---|---|---|
| Leader | `,` | Set in init.lua |
| Tab width | 2 spaces | expandtab, smarttab |
| Line numbers | absolute | relativenumber=false |
| Search | hlsearch, ignorecase+smartcase | |
| Scrolloff | 15 | |
| Color column | 120 | |
| Wrap | off | |
| Mouse | `a` (all modes) | |
| Encoding | UTF-8 | fileencodings includes cp936, gb18030, big5, euc-jp |
| Folding | indent-based, foldlevel=99 | |
| Backups/swap | disabled | |
| Hidden buffers | enabled | |
| termguicolors | enabled | |

---

## 6. Complete Keymap Reference (keymaps.lua + plugin configs)

### Core remaps
| Mode | Key | Action |
|---|---|---|
| n | `j`/`k` | `gj`/`gk` (display lines) |
| n | `gj`/`gk` | real `j`/`k` |
| n | `H` | `^` (line start) |
| n,v | `L` | `$` (line end) |
| n | `Y` | `y$` |
| n | `U` | `<C-r>` (redo) |
| n | `'` ↔ `` ` `` | swapped |
| n | `;` | `:` (command mode) |
| i | `kj` | `<Esc>` |
| n | `<Left>/<Right>/<Up>/<Down>` | disabled (arrow keys) |

### Search
| Mode | Key | Action |
|---|---|---|
| n | `<Space>` | `/` (start search) |
| n,v | `/` | `/\v` (very magic) |
| n | `n`/`N` | next/prev centered (`nzz`/`Nzz`) |
| n | `*`/`#` | swapped, centered |
| n | `g*` | `g*zz` |
| n | `,/` | `:nohls` (clear highlight) |

### Window/buffer/tab
| Mode | Key | Action |
|---|---|---|
| n | `<C-h/j/k/l>` | split navigation |
| n | `[b`/`]b` | prev/next buffer |
| n | `<Left>`/`<Right>` | prev/next buffer (overrides disabled arrows) |
| n | `,q` | smart close buffer |
| n | `<C-t>` | new tab |
| i | `<C-t>` | new tab |
| n | `,tt` | split terminal |
| n | `<C-e>`/`<C-y>` | 2× scroll |

### Leader mappings
| Key | Action | Source |
|---|---|---|
| `,n` | `:Neotree toggle` | keymaps.lua |
| `,p` | `:Telescope find_files` | keymaps.lua |
| `,f` | `:Telescope live_grep` | keymaps.lua |
| `,b` | `:Telescope buffers` | keymaps.lua |
| `,s` | `:Ag ` (prompt) | keymaps.lua |
| `,jd` | `vim.lsp.buf.definition()` | keymaps.lua |
| `,gd` | `vim.lsp.buf.declaration()` | keymaps.lua |
| `,ee` | `vim.diagnostic.open_float()` | keymaps.lua |
| `,t` | split terminal | keymaps.lua |
| `,tt` | split terminal | keymaps.lua |
| `,m` | `:MarkdownPreviewToggle` | keymaps.lua |
| `,run` | `:QuickRun` | keymaps.lua |
| `,us` | `:UltiSnipsEdit` | keymaps.lua |
| `,a` | EasyAlign (n+v) | keymaps.lua |
| `,<space>` | `:FixWhitespace` | keymaps.lua |
| `,sa` | select all (`ggVG`) | keymaps.lua |
| `,z` | toggle fold (`za`) | keymaps.lua |
| `,w` | force save (sudo) | keymaps.lua |
| `,g` | git add+commit+pull+push | keymaps.lua |
| `,bg` | toggle dark/light background | keymaps.lua |
| `,af` | `:Autoformat` | keymaps.lua |
| `,wr` | toggle wrap | keymaps.lua |
| `,rln` | toggle relative numbers | keymaps.lua |
| `,syn` | toggle syntax | keymaps.lua |
| `,git` | `:GitGutterToggle` | keymaps.lua |
| `,ln` | toggle line numbers | keymaps.lua |
| `,,h/j/k/l` | EasyMotion directional | keymaps.lua |
| `,,.` | EasyMotion repeat | keymaps.lua |

### F-keys
| Key | Action |
|---|---|
| `F1` | `<Esc>` (no help) |
| `F2` | `:CopilotChatToggle` (if copilot plugin present) |
| `F3` | `:Autoformat` |
| `F4` | toggle wrap |
| `F5` | `:QuickRun` |
| `F6` | toggle relative numbers |
| `F7` | toggle syntax |
| `F9` | `:TagbarToggle` |
| `F10` | toggle line numbers |
| `F12` | `:GitGutterToggle` |

### Completion (nvim-cmp, insert mode)
| Key | Action |
|---|---|
| `<C-j>` | next item |
| `<C-k>` | previous item |
| `<C-Space>` | trigger completion |
| `<CR>` | confirm selection |

### Snippets (UltiSnips, insert mode)
| Key | Action |
|---|---|
| `<Tab>` | expand / jump forward |
| `<S-Tab>` | jump backward |

### Multi-cursor (config.lua)
| Key | Action |
|---|---|
| `<C-d>` | select next occurrence |
| `<C-p>` | select previous |
| `<C-j>` | skip occurrence |
| `<Esc>` | quit |

### Neo-tree panel
| Key | Action |
|---|---|
| `l` / `<CR>` | open |
| `h` | collapse |
| `<Space>` | toggle node |

### Command-line
| Key | Action |
|---|---|
| `<C-a>` | Home |
| `<C-e>` | End |
| `<C-j>` | Down |
| `<C-k>` | Up |
| `w!!` | write with sudo |

### Visual mode
| Key | Action |
|---|---|
| `<` / `>` | indent and reselect |
| `H` / `L` | line start/end |

---

## 7. Autocommands (autocmds.lua)

| Event | Pattern | Behavior |
|---|---|---|
| InsertLeave | * | Disable paste mode |
| InsertLeave | * | Close preview window if no popup |
| BufReadPost | * | Restore cursor to last edit position |
| BufWinLeave | *.* | `mkview` (save folds/cursor) |
| BufWinEnter | *.* | `loadview` (restore folds/cursor) |
| FileType | cpp, c, javascript, java | `ts=2 sw=2 expandtab ai` |
| FileType | typescript | `formatprg=prettier --parser typescript` |
| BufRead/BufNewFile | *.md,*.mkd,*.markdown | Set filetype=markdown |
| BufRead/BufNewFile | *.part | Set filetype=html |
| FileType | html,css | `:EmmetInstall` |
| BufNewFile/BufRead | *.py | Map `#` insertion fix |
| BufWritePre | c,cpp,java,go,php,js,python,rust,etc. | Strip trailing whitespace |
| Syntax | * | Highlight TODO/FIXME/CHANGED/DONE/XXX/BUG/HACK/NOTE/INFO/IDEA |

---

## 8. LSP Configuration (lsp.lua)

**Pattern**: `setup_if_executable(server, binary, opts?)` — only enables a server if its binary is found on PATH.

| Server | Binary | Extra config |
|---|---|---|
| pyright | `pyright-langserver` | — |
| gopls | `gopls` | — |
| clangd | `clangd` | — |
| bashls | `bash-language-server` | — |
| jsonls | `vscode-json-language-server` | — |
| yamlls | `yaml-language-server` | — |
| graphql | `graphql-lsp` | — |
| solidity_ls | `solidity-language-server` | — |
| lua_ls | `lua-language-server` | globals={"vim"}, checkThirdParty=false |

**Diagnostics**: virtual text only for ERROR severity (icon prefix), no sign column signs, underline enabled, severity-sorted.

**Capabilities**: Enhanced with cmp-nvim-lsp if available.

**TypeScript**: Handled separately by `typescript-tools.nvim` (not via lspconfig).

---

## 9. Theme (theme.lua)

- **Colorscheme**: `gruvbox` (dark, hard contrast).
- **GUI fallback**: `solarized8_flat` with `FiraCode Nerd Font:h14.5`.
- **Custom highlights**: Red diagnostics for errors, orange (#ff8800) for warnings (both legacy `LspDiagnostics*` and new `Diagnostic*` groups).
- **Sign column**: linked to `LineNr` background.
- **Spell check**: underline-only (no background color).
- **Terminal cursor**: blinking bar (insert), underline (replace), block (normal).
- **Bracketed paste**: XTerm paste support enabled.

---

## 10. Operational Notes for Agents

### Editing rules
- **NEVER overwrite** `lua/config/private.lua` or `lua/config/private_config.lua` — these are user-personal and gitignored.
- Edits to files in this repo take effect immediately in Neovim (symlinks).
- The `lazy-lock.json` lives only in `~/.config/nvim/`, not in this repo.
- Plugin specs go in `lua/plugins/init.lua`. Plugin configs go in `lua/config/plugins/<name>.lua`.

### Adding a plugin
1. Add spec entry to `lua/plugins/init.lua`.
2. If config needed, create `lua/config/plugins/<name>.lua`.
3. Reference it in the spec: `config = function() require('config.plugins.<name>') end`.
4. Run `:Lazy sync` or `nvim --headless "+Lazy! sync" +qa`.

### Removing a plugin
1. Delete spec entry from `lua/plugins/init.lua`.
2. Delete config file from `lua/config/plugins/` if exists.
3. Remove any keymaps referencing the plugin from `keymaps.lua` (or the plugin won't error — mappings just won't do anything).
4. Run `:Lazy sync`.

### Dependencies
- `wilder.nvim` requires `:UpdateRemotePlugins` after install.
- `markdown-preview.nvim` builds via `bash install.sh` in plugin's `app/` dir.
- Lualine + bufferline + neo-tree use Nerd Font icons — install a Nerd Font.
- `nvim-emmet` requires `emmet-language-server` on PATH: `npm install -g @olrtg/emmet-language-server`.
- External tools: `ripgrep`, `ag` (silver_searcher), `universal-ctags`, `fzf` (all via `brew install`).

### Testing changes
- Open Neovim and verify no errors on startup.
- `:checkhealth` for diagnostics.
- `:Lazy` to verify plugin status.
- `:LspInfo` to check language servers.

### Key conventions
- All keymaps use `{ noremap = true, silent = true }` unless otherwise needed.
- Vimscript plugin settings are in `config.lua` (vim.g assignments).
- Lua plugin settings each get their own file in `lua/config/plugins/`.
- pcall wrapping is used for optional plugin loading (safe if plugin missing).
