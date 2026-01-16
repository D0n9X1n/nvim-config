-- ====================================================================
-- Wilder Configuration
-- ====================================================================

local ok, wilder = pcall(require, 'wilder')
if not ok then
  return
end

wilder.setup({ modes = { ':', '/', '?' } })

-- Basic popup menu renderer with a simple highlighing scheme.
wilder.set_option('renderer', wilder.popupmenu_renderer(wilder.popupmenu_border_theme({
  border = 'rounded',
  highlighter = wilder.basic_highlighter(),
})))
