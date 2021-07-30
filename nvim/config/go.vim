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

" use remote client
" let g:go_gopls_options = ['-remote=auto']
let g:go_gopls_enabled = 0

" XXX can I get gopls to run these?
" let g:ale_linters = {
" \   'go': ['vet', 'golint'],
" \}
