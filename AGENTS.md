# Agent Instructions

This is a **personal Neovim configuration** repo. It is symlinked into `~/.config/nvim/` via `install.sh`. Edits here immediately affect the user's Neovim.

## Architecture

```
init.lua                    ← entry point; sets leader, loads core configs, bootstraps lazy.nvim
lua/
  plugins/init.lua          ← all plugin specs for lazy.nvim (~60 plugins)
  config/
    settings.lua            ← vim.opt / vim.g editor options
    keymaps.lua             ← all key bindings (leader = comma)
    autocmds.lua            ← autocommands (filetype, whitespace, folds)
    theme.lua               ← colorscheme & custom highlight groups
    private.lua             ← [GITIGNORED] user's personal plugin specs
    private_config.lua      ← [GITIGNORED] user's personal overrides
    plugins/                ← per-plugin configuration files
      config.lua            ← vim.g settings for Vimscript plugins
      lsp.lua               ← LSP servers (conditional on binary availability)
      cmp.lua               ← nvim-cmp completion engine
      treesitter.lua        ← syntax highlighting
      telescope.lua         ← fuzzy finder
      neo-tree.lua          ← file explorer
      lualine.lua           ← statusline
      bufferline.lua        ← buffer tabs
      ultisnips.lua         ← snippet engine
      wilder.lua            ← command-line popup
      colorizer.lua         ← color highlights
      emmet.lua             ← HTML/CSS expansion
      markdown.lua          ← markdown rendering
      typescript-tools.lua  ← TypeScript support
UltiSnips/                  ← custom snippet files (all, python, js, c, cpp, go, php)
install.sh                  ← macOS installer (Homebrew deps, symlinks, private.lua template)
```

## Load Order

1. Leader key set to `,`
2. `config.settings` → `config.keymaps` → `config.autocmds` → `config.plugins.config`
3. lazy.nvim bootstrap + plugin loading (merges `config.private` if it exists)
4. `config.theme` → `config.private_config` (pcall, safe if missing)

## Plugin lazy-load events

When using `event = ...` in a plugin spec, **always pair `BufReadPost` with `BufNewFile`** (and `BufReadPre` with `BufNewFile`) so the plugin also loads for brand-new files (`nvim foo.cc` for a non-existent path). `BufReadPost` only fires when an existing file is read; `BufNewFile` covers the empty-buffer case.

```lua
{ 'some/plugin', event = { 'BufReadPost', 'BufNewFile' } }
```

Past bugs caused by `BufReadPost` alone: `<C-d>` (vim-visual-multi) and `,cc` (nerdcommenter) silently doing nothing on a fresh buffer.

## How to Add a Plugin

1. Add the plugin spec to `lua/plugins/init.lua` (Lua table with repo string)
2. If the plugin needs configuration, create `lua/config/plugins/<name>.lua`
3. Reference the config in the spec: `config = function() require('config.plugins.<name>') end`
4. If the plugin uses `vim.g` settings only, add them to `lua/config/plugins/config.lua` instead

## How to Remove a Plugin

1. Remove the spec from `lua/plugins/init.lua`
2. Delete or clean up its config file in `lua/config/plugins/`
3. Remove any related keymaps from `lua/config/keymaps.lua`
4. Remove any related `vim.g` settings from `lua/config/plugins/config.lua`
5. Remove any related autocommands from `lua/config/autocmds.lua`
6. Update `QUICKREF.md` (plugin table, keymap tables, file tree comment)

## How to Add a Keymap

Add to `lua/config/keymaps.lua` using:
```lua
map('n', '<leader>xx', ':SomeCommand<CR>', opts)
```
Convention: all mappings use `{ noremap = true, silent = true }` stored in `opts`.

## Coding Conventions

- **Indentation**: 2 spaces (Lua standard)
- **Comments**: `--` with `-- ====...====` section headers for major blocks
- **Naming**: `snake_case` for variables and functions
- **Plugin configs**: wrap setup calls in `pcall` when the plugin may not be installed
- **LSP servers**: use the `setup_if_executable(server, binary)` pattern in `lsp.lua`
- **No trailing whitespace**: autocmd strips it on save for most filetypes

## Validation

There are no automated tests. After making changes, verify with:

```
nvim --headless "+Lazy! sync" +qa        # plugins load without errors
nvim --headless "+lua print('ok')" +qa   # config parses without errors
```

Neovim also provides built-in health checks:
- `:checkhealth` — general diagnostics
- `:Lazy` — plugin install/update status
- `:LspInfo` — language server status

## Releases

**Every new tag is a release.** Whenever a version tag is pushed, a matching GitHub Release must be created — they go together, no exceptions.

Versioning follows SemVer (`vMAJOR.MINOR.PATCH`):
- **patch** (e.g. `v0.1.1` → `v0.1.2`) — bug fixes, doc-only updates
- **minor** (e.g. `v0.1.x` → `v0.2.0`) — new plugins, new keymaps, behavior changes
- **major** (e.g. `v0.x.x` → `v1.0.0`) — breaking changes to layout, leader, or required Neovim version

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

- Edit `private.lua` or `private_config.lua` — they are gitignored and personal
- Add `lazy-lock.json` to git — it is machine-specific
- Remove the lazy.nvim bootstrap block in `init.lua`
- Use `vim.cmd` for things that have a `vim.opt` / `vim.api` equivalent
- Add comments to self-evident code; only comment non-obvious logic
