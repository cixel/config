" colorscheme default
" colorscheme NeoSolarized
" set background=dark
set background=dark
" colorscheme base16-solarized-dark
" colorscheme dracula
" colorscheme base16-tomorrow-night
set notermguicolors
" let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_contrast_dark = 'hard'
colorscheme gruvbox

"
" powerline fonts
let g:airline_powerline_fonts = 1
"let g:airline_theme='powerlineish'
" let g:airline_theme='dracula'
" let g:airline_theme='base16_tomorrow'
let g:airline_theme='gruvbox'
" let g:airline_theme='solarized'
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
"" see vim-airline/doc/airline.txt for available symbol names and defaults
"let g:airline_symbols.notexists = ''
let g:airline_left_sep=''
let g:airline_right_sep=''
let g:airline_symbols.linenr = ''
let g:airline_symbols.maxlinenr = '☰'
let g:airline_left_alt_sep = ''
let g:airline_right_alt_sep = ''
" let g:airline#extensions#whitespace#checks = [ 'trailing', 'long' ]
let g:airline#extensions#whitespace#checks = [ 'trailing' ]
let g:airline#extensions#ale#enabled = 1
"let g:airline#extensions#whitespace#checks = [ 'trailing', 'long', 'mixed-indent-file' ]
let g:tmuxline_separators = {
    \ 'left' : '',
    \ 'right' : '',
    \ 'left_alt': '',
    \ 'right_alt' : '',
    \ 'space' : ' '}

" ale -- linting
let g:ale_sign_error = 'E'
let g:ale_sign_warning = 'W'
let g:ale_sign_style_warning = 'WS'
let g:ale_sign_style_error = 'WS'
let g:ale_list_window_size = 7
let g:ale_echo_msg_format = '%s (%linter%%:code%)'
