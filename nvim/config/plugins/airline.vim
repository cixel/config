let g:airline_powerline_fonts = 1
let g:airline_theme='gruvbox'

if !exists('g:airline_symbols')
	let g:airline_symbols = {}
endif

"" see vim-airline/doc/airline.txt for available symbol names and defaults
let g:airline_left_sep=''
let g:airline_right_sep=''
let g:airline_symbols.spell = ''
let g:airline_symbols.dirty='!'
let g:airline_symbols.linenr = ''
let g:airline_symbols.maxlinenr = '☰'
let g:airline_left_alt_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.colnr = ' '
let g:airline#extensions#whitespace#checks = [ 'trailing' ]
let g:airline#extensions#ale#enabled = 1
" as long as ale is giving me lsp errors via nvim-ale-diagnostic, disable
" extension for nvimlsp errors
let g:airline#extensions#nvimlsp#enabled = 0
"let g:airline#extensions#whitespace#checks = [ 'trailing', 'long', 'mixed-indent-file' ]
let g:tmuxline_separators = {
	\ 'left' : '',
	\ 'right' : '',
	\ 'left_alt': '',
	\ 'right_alt' : '',
	\ 'space' : ' '}
