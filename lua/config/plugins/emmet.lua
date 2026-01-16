-- ====================================================================
-- Emmet Configuration
-- ====================================================================

local ok, emmet = pcall(require, 'nvim-emmet')
if not ok then
  return
end

-- Compatibility with legacy autocmds calling :EmmetInstall.
vim.api.nvim_create_user_command('EmmetInstall', function()
  -- No default keymaps are added to avoid changing existing mappings.
end, {})
