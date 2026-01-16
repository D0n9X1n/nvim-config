-- ====================================================================
-- TypeScript Tools Configuration
-- ====================================================================

require('typescript-tools').setup({
  settings = {
    tsserver_file_preferences = {
      includeInlayParameterNameHints = 'none',
      includeInlayVariableTypeHints = false,
    },
  },
})
