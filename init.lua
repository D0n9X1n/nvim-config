-- ====================================================================
-- Neovim Configuration
-- Ported from m-vim (original by D0n9X1n)
-- Email: D0n9x1n@outlook.com
-- ====================================================================

-- Leader key
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Load base configurations (settings/keymaps/autocmds)
require("config.settings")
require("config.keymaps")
require("config.autocmds")
require("config.plugins.config")

-- ====================================================================
-- Bootstrap lazy.nvim
-- ====================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ====================================================================
-- Plugins spec (merge public + private)
-- ====================================================================
local spec = {
  -- load your normal plugins from lua/plugins/*.lua (your current structure)
  { import = "plugins" },
}

-- Optional: merge plugins from lua/config/private.lua (if exists)
-- private.lua should return a table like:
-- return { { "wakatime/vim-wakatime" }, { "folke/todo-comments.nvim", ... } }
local private_ok, private_plugins = pcall(require, "config.private")
if private_ok and type(private_plugins) == "table" then
  vim.list_extend(spec, private_plugins)
end

-- Setup lazy.nvim
require("lazy").setup(spec, {
  defaults = {
    lazy = false, -- load plugins at startup by default
  },
  install = {
    missing = true,
    colorscheme = { "default" },
  },
  checker = {
    enabled = false, -- set true if you want auto update checking
  },
})

-- ====================================================================
-- Theme (load after plugins)
-- ====================================================================
require("config.theme")

-- ====================================================================
-- Optional: load private custom configs (keymaps/settings/autocmds)
-- If you want, create lua/config/private_config.lua for personal settings.
-- ====================================================================
pcall(require, "config.private_config")
