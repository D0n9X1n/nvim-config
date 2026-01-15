-- ====================================================================
-- Neovim Configuration
-- Ported from m-vim (original by D0n9X1n)
-- Email: D0n9x1n@outlook.com
-- ====================================================================

-- Leader key
vim.g.mapleader = ','
vim.g.maplocalleader = ','

-- Load plugin configurations
require('config.settings')
require('config.keymaps')
require('config.autocmds')
require('config.plugins.config')

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require('lazy').setup('plugins', {
  defaults = { lazy = false },
  -- Also load optional plugins from private.lua if defined
  spec = {
    import = 'plugins',
  },
})

-- Load optional plugins from private.lua if user has defined them
local private_plugins_ok, private_plugins = pcall(require, 'config.private')
if private_plugins_ok and type(private_plugins) == 'table' then
  require('lazy').load({ plugins = private_plugins })
end

-- Load theme after plugins are installed
require('config.theme')

-- Load private customizations (if available)
local private_ok, _ = pcall(require, 'config.private')
if not private_ok then
  -- Private config not found, that's okay
end
