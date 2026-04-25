# Startup Performance — Lazy-Loading Design

## 1. Goal

Reduce Neovim startup time by ≥50% by giving every plugin in `lua/plugins/init.lua` an appropriate lazy-loading trigger, without changing user-visible behavior.

## 2. Background

Currently `init.lua` calls `lazy.nvim` with `defaults = { lazy = false }`. All ~48 plugins load eagerly at startup. Many are language-specific (only needed for `.ts`/`.md`/etc.), command-driven (Tagbar, QuickRun, fugitive), or only needed in insert mode (cmp, ultisnips, delimitMate). This bloats startup and contributes to perceived sluggishness, especially when opening large C++ files where the eager plugin chain runs before the buffer is even rendered.

The user has confirmed they want the **balanced** aggressiveness profile: conservative event/cmd/ft triggers for clearly deferrable plugins, plus `BufReadPost`/`InsertEnter` triggers for editing utilities. UI plugins (lualine, bufferline) load on `VeryLazy` since they're only needed once a buffer is visible.

Out of scope (separate spec cycles): plugin removal/replacement (B), modernization swaps like `gitsigns`/`conform` (C), large-file resilience guards (D), CI smoke test (E).

## 3. Design

### 3.1 Lazy-Trigger Assignment

Every plugin in `lua/plugins/init.lua` gets one of these triggers. Defaults stay at `lazy = false` for safety (existing behavior preserved for anything not explicitly tagged).

| Plugin | Trigger | Rationale |
|---|---|---|
| **Language syntax** | | |
| `leafgarland/typescript-vim` | `ft = { 'typescript', 'typescriptreact' }` | TS files only |
| `pangloss/vim-javascript` | `ft = { 'javascript', 'javascriptreact' }` | JS files only |
| `jparise/vim-graphql` | `ft = { 'graphql' }` | GraphQL files only |
| `HerringtonDarkholme/yats.vim` | `ft = { 'typescript', 'typescriptreact' }` | TS files only |
| `Quramy/tsuquyomi` | `ft = { 'typescript' }` | TS files only |
| `tomlion/vim-solidity` | `ft = { 'solidity' }` | Solidity only |
| **Treesitter / LSP / Completion** | | |
| `nvim-treesitter/nvim-treesitter` | `event = { 'BufReadPost', 'BufNewFile' }` | Needs a buffer |
| `neovim/nvim-lspconfig` | `event = { 'BufReadPre', 'BufNewFile' }` | LSP attaches per-buffer |
| `pmizio/typescript-tools.nvim` | `ft = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' }` | TS/JS LSP |
| `hrsh7th/nvim-cmp` | `event = { 'InsertEnter', 'CmdlineEnter' }` | Completion only in insert/cmdline |
| `SirVer/ultisnips` | `event = 'InsertEnter'` | Snippets are insert-only |
| **Editing utilities** | | |
| `Raimondi/delimitMate` | `event = 'InsertEnter'` | Insert-only |
| `docunext/closetag.vim` | `ft = { 'html', 'xml', 'jsx', 'tsx' }` | Markup only |
| `nvimdev/indentmini.nvim` | `event = 'BufReadPost'` | Off-by-default; load on demand |
| `junegunn/vim-easy-align` | `keys = { { '<Plug>(EasyAlign)', mode = { 'n', 'x' } } }`, `cmd = 'EasyAlign'` | Trigger-driven |
| `scrooloose/nerdcommenter` | `event = 'BufReadPost'` | Has `<leader>c…` keys |
| `tpope/vim-repeat` + `tpope/vim-surround` | `event = 'BufReadPost'` | Used in normal mode on buffers |
| `luochen1990/rainbow` | `event = 'BufReadPost'` | Per-buffer highlight |
| `unblevable/quick-scope` | `event = 'BufReadPost'` | Per-buffer movement helper |
| `terryma/vim-multiple-cursors` | `event = 'BufReadPost'` | Triggered by `<C-n>` etc. on buffers |
| `folke/todo-comments.nvim` | `event = 'BufReadPost'` | Per-buffer scanner |
| `Lokaltog/vim-easymotion` | `event = 'BufReadPost'` | Movement, `,,` keys; broad activation needed for `<Plug>` mappings |
| **HTML/CSS/Markdown** | | |
| `NvChad/nvim-colorizer.lua` | `event = 'BufReadPost'` | Per-buffer highlight |
| `olrtg/nvim-emmet` | `ft = { 'html', 'css', 'jsx', 'tsx', 'javascriptreact', 'typescriptreact' }` | Markup only |
| `MeanderingProgrammer/markdown.nvim` | (already `ft = 'markdown'`) | No change |
| `iamcco/markdown-preview.nvim` | (already `cmd`+`ft`) | No change |
| **Search / Tags** | | |
| `majutsushi/tagbar` | `cmd = { 'TagbarToggle', 'TagbarOpen', 'Tagbar' }` | Command-only |
| `bronson/vim-trailing-whitespace` | `cmd = 'FixWhitespace'` | Command-only |
| `dkprice/vim-easygrep` | `cmd = { 'Grep', 'GrepRoot', 'GrepBuffer', 'Replace', 'ReplaceUndo' }` | Command-only |
| `rking/ag.vim` | `cmd = { 'Ag', 'AgAdd', 'AgFromSearch' }` | Command-only |
| `dyng/ctrlsf.vim` | `cmd = { 'CtrlSF', 'CtrlSFOpen', 'CtrlSFToggle' }` + `keys = '\\'` | Command + keymap |
| **UI / Buffers** | | |
| `nvim-lualine/lualine.nvim` | `event = 'VeryLazy'` | Statusline can paint after buffer |
| `akinsho/bufferline.nvim` | `event = 'VeryLazy'` | Tabline can paint after buffer |
| `nvim-telescope/telescope.nvim` | `cmd = 'Telescope'`, `keys = { ',p',',f',',b' }` | Trigger-driven |
| `nvim-neo-tree/neo-tree.nvim` | `cmd = 'Neotree'`, `keys = ',n'` | Trigger-driven |
| **Git** | | |
| `tpope/vim-fugitive` | `cmd = { 'Git', 'G', 'Gdiffsplit', 'Gread', 'Gwrite', 'Ggrep', 'GMove', 'GDelete', 'GBrowse', 'GRemove', 'Gblame' }` | Command-only |
| `airblade/vim-gitgutter` | `event = 'BufReadPost'` | Per-buffer diff |
| **Misc tools** | | |
| `sjl/gundo.vim` | `cmd = 'GundoToggle'` | Command-only |
| `MikeCoder/quickrun.vim` | `cmd = 'QuickRun'` | Command-only |
| `gelguy/wilder.nvim` | `event = 'CmdlineEnter'` | Cmdline-only |
| **Formatter / Editor** | | |
| `gpanders/editorconfig.nvim` | `event = { 'BufReadPre', 'BufNewFile' }` | Pre-buffer |
| `Chiel92/vim-autoformat` | `cmd = 'Autoformat'`, `keys = { '<F3>', '<leader>af' }` | Trigger-driven |
| **Colorschemes** | | |
| `MOSconfig/gruvbox` | `lazy = false, priority = 1000` | Default theme — must load first |
| `MOSconfig/vim-solarized8`, `chriskempson/base16-vim`, `sainnhe/everforest`, `ayu-theme/ayu-vim`, `MOSconfig/NeoSolarized.nvim` | `lazy = true` | Loaded only when user runs `:colorscheme X` |

### 3.2 Lazy.nvim Defaults Change

`init.lua`: keep `defaults = { lazy = false }` unchanged. We **opt-in per plugin** rather than flipping the global default. This keeps any plugin not in the table above behaving exactly as today, eliminating risk of unintentionally breaking something.

### 3.3 Keymap Compatibility

Several keymaps in `lua/config/keymaps.lua` reference commands of now-lazy plugins (e.g. `:Neotree toggle`, `:Telescope find_files`, `:Autoformat`, `:TagbarToggle`, `:GundoToggle`, `:QuickRun`, `:GitGutterToggle`, `:MarkdownPreviewToggle`, `:CtrlSF`). These already work because lazy.nvim creates command-stubs for `cmd`-tagged plugins. **No keymap changes required**, but the smoke test (§4) verifies each.

For `keys`-tagged plugins (`telescope`, `neo-tree`, `easy-align`, `ctrlsf`, `vim-autoformat`), the `keys` entries match the existing keymaps so first press triggers load + execute.

### 3.4 Colorscheme Bootstrap

`lua/config/theme.lua` runs `vim.cmd('colorscheme gruvbox')` after `lazy.setup`. With gruvbox marked `lazy = false, priority = 1000`, lazy.nvim guarantees it loads before any other plugin and before theme.lua runs. Other colorschemes become discoverable via `:colorscheme <name>` (lazy.nvim auto-loads them on the colorscheme command).

## 4. Test Strategy

### 4.1 Numeric: Startup Time

```bash
# Baseline (before changes — capture once before merge)
nvim --headless --startuptime /tmp/nvim-before.log +qa
awk 'END{print $1}' /tmp/nvim-before.log    # final timestamp = total ms

# After
nvim --headless --startuptime /tmp/nvim-after.log +qa
awk 'END{print $1}' /tmp/nvim-after.log
```

**Pass criterion:** `after ≤ 0.5 × before` (≥50% reduction). Run 3 times each, take median.

### 4.2 Smoke: Per-Plugin Activation

Headless smoke matrix. Each row asserts the plugin loads when its trigger fires.

| Trigger | Command | Expected |
|---|---|---|
| Open `.ts` | `nvim --headless +'e test.ts' +'lua print(vim.bo.filetype)' +qa` | `typescript`; `:LspInfo` shows `typescript-tools` attached |
| Open `.md` | open + check markdown.nvim loaded | loaded |
| Open `.html` | open + `:lua print(vim.fn.exists(':Emmet'))` | non-zero |
| Open `.cpp` | open + check treesitter highlighter active | active |
| `:Telescope` | open + run | telescope window opens |
| `:Neotree` | open + run | neo-tree opens |
| `:TagbarToggle` | open + run | tagbar opens |
| `:Autoformat` | open + run | command exists |
| `:Git status` | open + run | fugitive command works |
| `:GundoToggle` | open + run | gundo opens |
| `:QuickRun` | open + run | quickrun command exists |
| `:CtrlSF foo` | open + run | command exists |
| `,p` | feedkeys then check telescope buf | telescope opened |
| `,n` | feedkeys then check neo-tree buf | neo-tree opened |
| `<F3>` | feedkeys, then check `:Autoformat` exists | command exists |
| Insert mode | `:startinsert`, check `delimitMate` mappings active | `<` autopair works |

Smoke tests live as a single shell script `scripts/smoke.sh` (created in implementation, not in this spec). All asserts must pass.

### 4.3 Manual Validation

After automated checks:
1. `nvim init.lua` — confirm UI looks identical (statusline, tabline, theme).
2. Open a real C++ file from a project — confirm no functional regression.
3. `:Lazy` — confirm plugins show appropriate `event/cmd/ft/keys` instead of all "loaded at startup".

## 5. Non-Goals

- Removing or replacing any plugin (deferred to spec B).
- Modernizing `vim-gitgutter` → `gitsigns`, `vim-autoformat` → `conform`, etc. (deferred to C).
- Large-file feature toggling (the user explicitly opted out — D dropped).
- Adding `which-key`, `trouble`, `telescope-fzf-native` (deferred to C).
- Adding CI (deferred to E).
- Changing keymaps, settings, autocmds, or theme.

## 6. Open Questions

None. All design decisions answered during brainstorming:
- Aggressiveness: balanced ✓
- Big-file mode: dropped ✓
- Verification: numeric ≥50% target + per-plugin smoke ✓

## 7. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `<Plug>` mappings (easymotion, easy-align) require plugin loaded before keypress | Use `event = 'BufReadPost'` for easymotion (broad), `keys = { '<Plug>(EasyAlign)', mode={'n','x'} }` for easy-align |
| Colorscheme race (theme.lua runs before gruvbox loads) | `priority = 1000` on gruvbox forces it to load first |
| `cmp` only loads on InsertEnter — first `<Tab>` in insert may have a tiny stall | Acceptable; lazy.nvim load is <50ms typical |
| Wilder needs `:UpdateRemotePlugins` — lazy on `CmdlineEnter` may delay first `:` | Acceptable; build step still runs at install |
| Some keymap that calls a plugin function directly (not via command) might fire before the plugin loads | Audit `keymaps.lua` during implementation; convert any direct `require('plugin').fn()` to `keys` triggers or leave plugin eager |
