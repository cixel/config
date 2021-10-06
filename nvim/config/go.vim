" let g:go_metalinter_deadline = "5s"
let g:go_fmt_fail_silently = 1
" let g:go_metalinter_enabled = [
"       \ 'deadcode', 'errcheck', 'gas', 'goconst', 'golint', 'gosimple',
"       \ 'gotype', 'ineffassign', 'interfacer', 'staticcheck', 'structcheck',
"       \ 'unconvert', 'varcheck', 'vet', 'vetshadow',
"       \ ]

" let g:go_fmt_command = "goimports" " swap gofmt for goimports so that imports are autocleaned
" let g:go_metalinter_command = "golangci-lint"
" let g:go_metalinter_command = "gopls"
" let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck']
" let g:go_imports_autosave = 1
" let g:go_fmt_command = "gopls"

" let g:go_highlight_build_constraints = 1
" let g:go_highlight_extra_types = 1
" let g:go_highlight_fields = 1
" let g:go_highlight_functions = 1
" let g:go_highlight_methods = 1
" let g:go_highlight_structs = 1
"let g:go_highlight_operators = 1
"let g:go_highlight_types = 1
"let g:go_auto_sameids = 1

" don't do that weird hello world template
let g:go_template_autocreate = 0

let g:go_highlight_chan_whitespace_error = 0
let g:go_highlight_extra_types = 0
let g:go_highlight_space_tab_error = 0
let g:go_highlight_trailing_whitespace_error = 0
let g:go_highlight_operators = 0
let g:go_highlight_functions = 0
let g:go_highlight_function_parameters = 0
let g:go_highlight_function_calls = 0
let g:go_highlight_types = 0
let g:go_highlight_fields = 0
let g:go_highlight_build_constraints = 0
let g:go_highlight_generate_tags = 0
let g:go_highlight_string_spellcheck = 0
let g:go_highlight_format_strings = 0
let g:go_highlight_variable_declarations = 0
let g:go_highlight_variable_assignments = 0
let g:go_highlight_diagnostic_errors = 0
let g:go_highlight_diagnostic_warnings = 0

" use remote client
" let g:go_gopls_options = ['-remote=auto']
let g:go_gopls_enabled = 0
let g:go_fold_enable = []

" disable features redundant with nvim-lsp
let g:go_code_completion_enabled = 0
let g:go_fmt_autosave = 0
let g:go_imports_autosave = 0

" XXX can I get gopls to run these?
" let g:ale_linters = {
" \   'go': ['vet', 'golint'],
" \}
