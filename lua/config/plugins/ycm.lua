-- ====================================================================
-- YouCompleteMe Configuration
-- ====================================================================

local g = vim.g

g.ycm_show_diagnostics_ui = 1
g.ycm_enable_diagnostic_signs = 0
g.ycm_enable_diagnostic_highlighting = 1
g.ycm_key_list_select_completion = { '<Down>' }
g.ycm_key_list_previous_completion = { '<Up>' }
g.ycm_complete_in_comments = 1
g.ycm_complete_in_strings = 1
g.ycm_use_ultisnips_completer = 1
g.ycm_collect_identifiers_from_comments_and_strings = 1
g.ycm_collect_identifiers_from_tags_files = 1
g.ycm_max_num_candidates = 5
g.ycm_autoclose_preview_window_after_completion = 1
g.ycm_min_num_identifier_candidate_chars = 2
g.ycm_seed_identifiers_with_syntax = 1
g.ycm_key_list_stop_completion = { '<CR>' }
g.ycm_goto_buffer_command = 'horizontal-split'
g.ycm_register_as_syntastic_checker = 1

-- Semantic triggers for TypeScript
if not g.ycm_semantic_triggers then
  g.ycm_semantic_triggers = {}
end
g.ycm_semantic_triggers['typescript'] = { '.' }
