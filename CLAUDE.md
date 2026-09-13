# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

This is a personal Lua-based Neovim configuration for Neovim 0.12+. `install.sh` symlinks the checkout into `~/.config/nvim`, so edits here can affect the user's active editor immediately. lazy.nvim is bootstrapped by `init.lua`; there is no application build or standalone linter.

## Commands

```sh
# Canonical validation: isolated lazy-loading and regression matrix
bash scripts/smoke.sh

# Syntax-check all tracked Lua entry points without loading the config
nvim --headless -u NONE -i NONE -n "+lua local ok,e=pcall(function() assert(loadfile('init.lua')); for _,f in ipairs(vim.fn.systemlist('git ls-files lua')) do assert(loadfile(f),f) end end); if not ok then print(e); vim.cmd('cquit 1') end" +qa

# Focused single-file syntax check
nvim --headless -u NONE -i NONE -n "+lua if not loadfile('lua/config/theme.lua') then vim.cmd('cquit 1') end" +qa

# Focused runtime assertion against the installed/live config
nvim --headless "+lua if vim.g.colors_name ~= 'apollo' then vim.cmd('cquit 1') end" +qa

# Install, update, and remove plugins to match the spec
nvim --headless "+Lazy! sync" +qa

# Profile startup
nvim --headless --startuptime /tmp/nvim-startup.log +qa
```

`scripts/smoke.sh` is the must-pass test (Python 3 and installed plugins required). It copies tracked public runtime files into a temporary config, excludes private extensions, isolates state/cache/data and lockfiles, disables ShaDa, and refuses missing plugin/parser installation. It runs installer fixtures, error-detection negative controls, and functional keymap/Treesitter/directory/diagnostic regressions. Plugins are read from the existing installation. Headless Neovim can exit zero after Lua errors: use explicit `cquit` on assertion failure, or the smoke probe wrapper, rather than trusting `+qa` alone.

For interactive diagnosis, use `:checkhealth`, `:Lazy`, and `:LspInfo`.

## Architecture

`init.lua` is the composition root. Its order is significant:

1. Reject Neovim older than 0.12, then set both leader keys to `,`.
2. Load `config.settings`, `config.keymaps`, `config.autocmds`, then legacy Vimscript-plugin globals from `config.plugins.config`.
3. Bootstrap lazy.nvim and import the plugin specs from `lua/plugins/init.lua`.
4. Merge optional specs returned by gitignored `config.private`.
5. Load `config.theme` after plugins, then optional gitignored `config.private_config` overrides.

Plugin declarations and configuration are intentionally split:

- `lua/plugins/init.lua` owns dependency declarations and lazy-loading triggers.
- `lua/config/plugins/<name>.lua` owns a Lua plugin's setup.
- `lua/config/plugins/config.lua` consolidates `vim.g` settings for Vimscript plugins.
- `lua/config/keymaps.lua` and `lua/config/autocmds.lua` own cross-plugin mappings and lifecycle behavior.
- `UltiSnips/` contains the bundled language snippet sources.

The default theme is `apollo-theme/nvim-apollo-theme`, which must stay eager with priority `1000`; `lua/config/theme.lua` activates `apollo` and applies project-specific highlight overrides. Neo-tree is also eager because it owns directory startup. Bufferline, lualine, and UltiSnips are deliberately eager; the smoke matrix protects these decisions and the Neo-tree/Bufferline directory-startup behavior.

Treesitter is eager on its explicit `main` branch and uses the Neovim 0.12 API. Parsers are installed explicitly with `:TSInstall`; startup never downloads them. Bundled parser queries fall back to the plugin's `runtime` directory. Smoke tests assert actual highlight captures and reindentation, not just plugin load state.

LSP setup in `lua/config/plugins/lsp.lua` uses the Neovim 0.11 `vim.lsp.config`/`vim.lsp.enable` API. `setup_if_executable` skips servers whose binaries are absent. TypeScript and JavaScript are handled separately by `typescript-tools.nvim`.

## Lazy-loading invariants

When a buffer event should also work for a path that does not exist yet, pair `BufReadPost` with `BufNewFile`, and pair `BufReadPre` with `BufNewFile`. `BufReadPost` alone previously left NerdCommenter and vim-visual-multi unavailable in fresh buffers.

Command- and key-triggered plugins rely on lazy.nvim stubs. Keep each trigger in `lua/plugins/init.lua` aligned with mappings in `lua/config/keymaps.lua` and assertions in `scripts/smoke.sh`.

When adding or removing a plugin, update its spec, per-plugin config, keymaps/autocommands or `vim.g` settings, smoke coverage, and relevant `README.md` documentation together.

## Local and generated state

Do not edit or replace `lua/config/private.lua` or `lua/config/private_config.lua`; they are gitignored personal extension points. Do not add `lazy-lock.json`, which is machine-local. Preserve the lazy.nvim bootstrap in `init.lua`.

## Releases

Tags and GitHub Releases are paired. Version tags use `vMAJOR.MINOR.PATCH`: patch for fixes/docs, minor for plugins/keymaps/behavior, and major for breaking layout, leader-key, or Neovim-version changes. Creating a tag requires creating its matching GitHub Release.
