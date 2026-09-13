-- ====================================================================
-- Treesitter Configuration (Neovim 0.12+, nvim-treesitter main)
-- ====================================================================

local treesitter = require('nvim-treesitter')
treesitter.setup({})
assert(type(treesitter.indentexpr) == 'function', 'nvim-treesitter main indentexpr API is required')

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('ConfigTreesitter', { clear = true }),
  callback = function(event)
    -- Neovim 0.12 returns nil when no parser is available. Keep ordinary
    -- filetype indentation in that case; parser installation is manual.
    if not vim.treesitter.get_parser(event.buf) then
      return
    end
    vim.treesitter.start(event.buf)
    vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
