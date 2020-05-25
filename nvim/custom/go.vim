" go-vim stuff
"let g:neomake_go_enabled_makers = ['']
"let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck'] " remove golint fromt the defaults
" let g:ale_go_langserver_executable = 'gopls'
" let g:ale_go_gometalinter_options = '
"   \ --aggregate
"   \ --sort=line
"   \ --vendor
"   \ --vendored-linters
"   \ --disable=gas
"   \ --disable=goconst
"   \ --disable=gocyclo
"   \ '
  " \ --severity=errcheck:warning
  " \ --fast
" let g:ale_linters = {'go': ['gopls']}
" let g:go_metalinter_deadline = "5s"
let g:go_fmt_fail_silently = 1
" let g:go_metalinter_enabled = [
"       \ 'deadcode', 'errcheck', 'gas', 'goconst', 'golint', 'gosimple',
"       \ 'gotype', 'ineffassign', 'interfacer', 'staticcheck', 'structcheck',
"       \ 'unconvert', 'varcheck', 'vet', 'vetshadow',
"       \ ]
" let g:go_metalinter_enabled = [
"       \ 'deadcode', 'errcheck', 'gas', 'goconst', 'gosimple',
"       \ 'ineffassign', 'interfacer', 'staticcheck', 'structcheck',
"       \ 'unconvert', 'varcheck', 'vet', 'vetshadow',
"       \ ]  " 'golint',

" let g:go_fmt_command = "goimports" " swap gofmt for goimports so that imports are autocleaned
" let g:go_metalinter_command = "golangci-lint"
let g:go_metalinter_command = "gopls"
" let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck']
let g:go_imports_autosave = 1
let g:go_fmt_command = "gopls"

let g:go_highlight_build_constraints = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
"let g:go_highlight_operators = 1
"let g:go_highlight_types = 1
"let g:go_auto_sameids = 1


let g:ale_linters = {
\   'go': ['vet', 'golint'],
\}
