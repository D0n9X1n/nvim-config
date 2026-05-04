# Copilot Instructions

Personal Neovim configuration using **lazy.nvim**. Symlinked into `~/.config/nvim/` — edits take effect immediately.

## Agent Framework

This project uses the [feature-crew](https://github.com/D0n9X1n/feature-crew) agent framework (vendored as a git submodule at `feature-crew/`).

Read and follow `feature-crew/.github/copilot-instructions.md` for all development workflows.

When the user asks to build, fix, or change anything non-trivial:
1. Act as the PM — discuss requirements, produce a spec
2. Dispatch agents from `feature-crew/agents/` following `feature-crew/workflow/pipeline.md`
3. Run all independent work in parallel

Agent templates: `feature-crew/agents/`
Pipeline definition: `feature-crew/workflow/pipeline.md`

For trivial single-file edits (typo fixes, small config tweaks), proceed directly without dispatching the full pipeline.

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

## Releases

**Every new tag is a release.** Whenever a version tag is pushed, a matching GitHub Release must be created — they go together, no exceptions.

Versioning follows SemVer (`vMAJOR.MINOR.PATCH`):
- **patch** (`v0.1.1` → `v0.1.2`) — bug fixes, doc-only updates
- **minor** (`v0.1.x` → `v0.2.0`) — new plugins, new keymaps, behavior changes
- **major** (`v0.x.x` → `v1.0.0`) — breaking changes to layout, leader, or required Neovim version

Standard release flow:

```sh
# 1. commit the change
git commit -am "fix(scope): short description"

# 2. tag (annotated)
git tag -a vX.Y.Z -m "vX.Y.Z: short description"

# 3. push commit and tag
git push origin main
git push origin vX.Y.Z

# 4. create the GitHub Release (REQUIRED for every tag)
gh release create vX.Y.Z \
  --title "vX.Y.Z — short description" \
  --notes "## Changes
- ...

**Full Changelog**: https://github.com/D0n9X1n/nvim-config/compare/vPREV...vX.Y.Z"
```

Find the previous tag with `git tag --sort=-v:refname | head -2`.

## Do NOT

- Edit `private.lua` or `private_config.lua` — gitignored and personal
- Add `lazy-lock.json` to git — machine-specific
- Remove the lazy.nvim bootstrap block in `init.lua`

## Reference

See `AGENTS.md` for full architecture details and `QUICKREF.md` for complete plugin inventory, keymap tables, and LSP server list.
