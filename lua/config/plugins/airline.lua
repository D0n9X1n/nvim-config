-- ====================================================================
-- Airline Configuration
-- ====================================================================

local g = vim.g

g.airline_powerline_fonts = 0
g.airline_left_sep = ''
g.airline_right_sep = ''
g.airline_left_alt_sep = '❯'
g.airline_right_alt_sep = '❮'

if not g.airline_symbols then
  g.airline_symbols = {}
end

-- Unicode symbols
g.airline_symbols.branch = ''
g.airline_symbols.readonly = ''
g.airline_symbols.crypt = '🔒 '
g.airline_symbols.linenr = ' '
g.airline_symbols.paste = 'ρ'
g.airline_symbols.colnr = '⎇ '
g.airline_symbols.maxlinenr = '☰'
g.airline_symbols.notexists = '!∄!'
g.airline_symbols.spell = 'Ꞩ '
g.airline_symbols.whitespace = 'Ξ'

-- Tabline
g['airline#extensions#tabline#enabled'] = 1
g['airline#extensions#tabline#buffer_nr_show'] = 1
g['airline#extensions#tabline#formatter'] = 'unique_tail_improved'

-- Whitespace extension
g['airline#extensions#whitespace#enabled'] = 1
