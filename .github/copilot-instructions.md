# Copilot Instructions

This is a Neovim configuration repo using **lazy.nvim** as the plugin manager.

## Key Facts

- Entry point: `init.lua` → loads core configs then bootstraps lazy.nvim
- Plugin specs: `lua/plugins/init.lua` (single file, ~60 plugins)
- Per-plugin configs: `lua/config/plugins/<name>.lua`
- Vimscript plugin settings: `lua/config/plugins/config.lua` (vim.g assignments)
- Keymaps: `lua/config/keymaps.lua` (leader is `,`)
- LSP servers are conditionally enabled via `setup_if_executable(server, binary)`
- Private overrides live in gitignored `private.lua` / `private_config.lua`

## When Editing This Repo

- Use 2-space indentation (Lua standard)
- Use `snake_case` for variables and functions
- Wrap optional plugin setups in `pcall`
- When adding/removing a plugin, update all related files: spec, config, keymaps, autocmds, QUICKREF.md
- Validate with `nvim --headless "+Lazy! sync" +qa` and `nvim --headless "+lua print('ok')" +qa`
- See `AGENTS.md` for full architecture and conventions
