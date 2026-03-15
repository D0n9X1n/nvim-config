# Copilot Instructions

Personal Neovim configuration using **lazy.nvim**. Symlinked into `~/.config/nvim/` — edits take effect immediately.

## Validation

There are no tests or linters. After any change, verify with:

```sh
nvim --headless "+Lazy! sync" +qa        # plugins load without errors
nvim --headless "+lua print('ok')" +qa   # config parses without errors
```

## Architecture

### Load order (`init.lua`)

1. Leader key set to `,`
2. `config.settings` → `config.keymaps` → `config.autocmds` → `config.plugins.config`
3. lazy.nvim bootstrap + plugin loading (merges `config.private` specs if file exists)
4. `config.theme` → `config.private_config` (pcall, safe if missing)

### Plugin system — two-file pattern

- **Specs** go in `lua/plugins/init.lua` (single file, all ~60 plugins).
- **Lua plugin configs** each get their own file at `lua/config/plugins/<name>.lua`, referenced in the spec via `config = function() require('config.plugins.<name>') end`.
- **Vimscript plugin settings** (`vim.g` assignments) are consolidated in `lua/config/plugins/config.lua`.

### LSP — conditional setup

`lua/config/plugins/lsp.lua` uses `setup_if_executable(server, binary)` which only enables a server if its binary is on PATH. Uses the Neovim 0.11+ `vim.lsp.config` / `vim.lsp.enable` API. TypeScript is handled separately by `typescript-tools.nvim`, not lspconfig.

## Conventions

- **2-space indentation**, `snake_case` naming
- **Section headers**: `-- ====...====` comment blocks for major sections
- **Keymaps**: all use `{ noremap = true, silent = true }` stored in a shared `opts` variable
- **pcall wrapping**: use `pcall(require, ...)` for anything that may not be installed
- Prefer `vim.opt` / `vim.api` over `vim.cmd`; only comment non-obvious logic

## How to Add a Plugin

1. Add spec to `lua/plugins/init.lua`
2. If config needed, create `lua/config/plugins/<name>.lua`
3. Reference it: `config = function() require('config.plugins.<name>') end`
4. If the plugin only needs `vim.g` settings, add them to `lua/config/plugins/config.lua` instead
5. Add any keymaps to `lua/config/keymaps.lua`
6. Update `QUICKREF.md`

## How to Remove a Plugin

1. Remove spec from `lua/plugins/init.lua`
2. Delete config from `lua/config/plugins/` if it exists
3. Remove related keymaps from `lua/config/keymaps.lua`
4. Remove related `vim.g` settings from `lua/config/plugins/config.lua`
5. Remove related autocommands from `lua/config/autocmds.lua`
6. Update `QUICKREF.md`

## Do NOT

- Edit `private.lua` or `private_config.lua` — gitignored and personal
- Add `lazy-lock.json` to git — machine-specific
- Remove the lazy.nvim bootstrap block in `init.lua`

## Reference

See `AGENTS.md` for full architecture details and `QUICKREF.md` for complete plugin inventory, keymap tables, and LSP server list.
