-- ====================================================================
-- Markdown Configuration
-- ====================================================================

local ok, markdown = pcall(require, 'markdown')
if not ok then
  return
end

markdown.setup({})
