call plug#begin()
" Plug 'fatih/vim-go', { 'tag': '*', 'do': ':GoUpdateBinaries'}
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }

Plug 'editorconfig/editorconfig-vim'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
Plug 'zchee/deoplete-go', { 'do': 'make' }
Plug 'mdempsky/gocode', { 'rtp': 'nvim', 'do': '~/.nvim/plugged/gocode/nvim/symlink.sh' }

Plug 'majutsushi/tagbar' " source code nav in sidebar
Plug 'w0rp/ale'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'alvan/vim-closetag'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/nerdcommenter'
Plug 'mtth/scratch.vim'
Plug 'SirVer/ultisnips'
Plug 'godlygeek/tabular'
Plug 'Raimondi/delimitMate'
Plug 'christoomey/vim-tmux-navigator'
Plug 'cohama/lexima.vim' " not sure if I use this
Plug 'ervandew/supertab'
Plug 'idanarye/vim-dutyl'
Plug 'milkypostman/vim-togglelist' " toggle loclist and quickfix
Plug 'rhysd/vim-crystal' " support for crystal lang
Plug 'leafgarland/typescript-vim'
Plug 'christianrondeau/vim-base64' " base64 encode/decode
Plug 'cespare/vim-toml'

Plug 'plasticboy/vim-markdown'

" C++
Plug 'rip-rip/clang_complete'

" Rust
Plug 'rust-lang/rust.vim'
Plug 'racer-rust/vim-racer'
Plug 'sebastianmarkow/deoplete-rust'

" PHP
Plug 'StanAngeloff/php.vim'
Plug 'padawan-php/deoplete-padawan', { 'do': 'composer install' }

" i don't really use these
" https://github.com/jceb/vim-orgmode/blob/master/doc/orgguide.txt
Plug 'jceb/vim-orgmode'
Plug 'tpope/vim-speeddating'

Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'chriskempson/base16-vim'
Plug 'iCyMind/NeoSolarized'
Plug 'morhetz/gruvbox'

"Plug 'maksimr/vim-jsbeautify'
"Plug 'Chiel92/vim-autoformat'
Plug 'sbdchd/neoformat'

Plug 'tpope/vim-fugitive' " I should look into actually using this
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'vim-scripts/VisIncr'

Plug 'elzr/vim-json'
" Plug 'othree/yajs.vim', { 'for': 'javascript' } " better syntax for javascript ** Very slow. Look into replacement
Plug 'pangloss/vim-javascript'
call plug#end()

syntax on
filetype plugin indent on
let mapleader=","

" Potential performance improvemenets (scrolling)
set noshowcmd
set nolazyredraw

" base64 encoding/decoding
" Visual Mode mappings
vnoremap <silent> <leader>B c<c-r>=base64#decode(@")<cr><esc>`[v`]h
vnoremap <silent> <leader>b c<c-r>=base64#encode(@")<cr><esc>`[v`]h

" Regex mappings
nnoremap <leader>b/ :%s/\v()/\=base64#encode(submatch(1))/<home><right><right><right><right><right><right>
nnoremap <leader>B/ :%s/\v()/\=base64#decode(submatch(1))/<home><right><right><right><right><right><right>

" set folding method to be language defined and files are not folded when
" opened
set foldmethod=syntax
set foldlevelstart=20
"set nofoldenable

" let g:python_host_prog = '/usr/local/bin/python3'
" let g:python_host_prog = '/usr/local/bin/python2'
" let g:python2_host_prog = '/usr/local/bin/python2'
let g:python_host_prog = '/usr/local/bin/python3'
let g:python3_host_prog = '/usr/local/bin/python3'

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
let g:airline#extensions#whitespace#checks = [ 'trailing', 'long' ]
"let g:airline#extensions#whitespace#checks = [ 'trailing', 'long', 'mixed-indent-file' ]
let g:tmuxline_separators = {
    \ 'left' : '',
    \ 'right' : '',
    \ 'left_alt': '',
    \ 'right_alt' : '',
    \ 'space' : ' '}

" yank to clipboard
set clipboard=unnamed

" do not require scratch/fileless buffers to be saved
set hidden

" colorscheme default
" colorscheme NeoSolarized
" set background=dark
set background=dark
" colorscheme base16-solarized-dark
" colorscheme dracula
" colorscheme base16-tomorrow-night
colorscheme gruvbox

" indentation settings for using hard tabs for indent. Display tabs as
" four characters wide.
set shiftwidth=4
set tabstop=4

"set list          " Display unprintable characters f12 - switches
"set listchars=tab:•\ ,trail:•,extends:»,precedes:« " Unprintable chars mapping

" line numbers on by default
set number
autocmd InsertEnter * silent! :set norelativenumber
autocmd InsertLeave,BufNewFile,VimEnter * silent! :set relativenumber
autocmd FocusLost * :set number
autocmd FocusGained * :set relativenumber

" plugin
:nmap \o :set paste!<CR>

" changes j and k to move by row instead of by line
:nmap j gj
:nmap k gk

" search incrementally, emacs style
:set incsearch
" other search options
:set ignorecase
:set smartcase
:set nohlsearch

" swap back and forth between 2 files
:nmap <C-e> :e#<CR>

" next/previous buffer
:nmap <C-n> :bnext<CR>
:nmap <C-m> :bprev<CR>

" js-beautify
":nnoremap <leader>ff :%!js-beautify --editorconfig -q -f -<CR>
"autocmd FileType javascript noremap <buffer>  <c-f> :call JsBeautify()<cr>
"autocmd FileType javascript noremap <buffer>  <leader>ff :call JsBeautify()<cr>
"autocmd FileType javascript noremap <buffer>  <leader>ff :Autoformat<cr>
au BufNewFile,BufRead *.ejs set filetype=html
autocmd FileType javascript noremap <buffer>  <leader>ff :Neoformat<cr>
" let g:neoformat_javascript_jscs = {
"             \ 'exe': 'eslint_d',
" 			\ 'args': ['--fix', '--no-colors', '--reporter', 'inline'],
"             \ 'stdin': 1,
"             \ 'no_append': 1,
"             \ }
let g:neoformat_enabled_javascript = ['eslint_d']
" if I uncomment this, undo will skip over neoformat changes and undo the last
" change which was mine
"augroup fmt
  "autocmd!
  "autocmd BufWritePre * undojoin | Neoformat
"augroup END

"let g:formatters_js = ['jscs']
"nmap <leader>.. :lclose<CR>
nmap <script> <silent> <leader>.. :call ToggleLocationList()<CR>

" ale -- linting
let g:ale_sign_error = 'E'
let g:ale_sign_warning = 'W'
let g:ale_sign_style_warning = 'WS'
let g:ale_sign_style_error = 'WS'
let g:ale_list_window_size = 7
let g:ale_echo_msg_format = '%s (%linter%)'
"let g:ale_linters = {
"\   'javascript': ['eslint'],
"\}
"let g:ale_open_list = 'on_save'
nmap <silent> <C-Q> <Plug>(ale_previous_wrap)
nmap <silent> <C-q> <Plug>(ale_next_wrap)

" FZF.vim
let $FZF_DEFAULT_COMMAND = 'ag --hidden --ignore-dir={dist,target,node_modules,docs,rulepack/xml,experiments} --ignore .git -g ""'
set rtp+=/usr/local/opt/fzf " for fzf to load on start from the brew install
nmap ; :FZF<CR>

" UltiSnips
" Trigger configuration. Do not use <tab>
let g:UltiSnipsExpandTrigger="<c-q>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"
let g:SuperTabDefaultCompletionType = "<c-tab>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" deoplete
let g:deoplete#enable_at_startup = 1
"let g:tern_show_signature_in_pum = '0'
"autocmd CompleteDone * silent! pclose! *.js
autocmd CompleteDone * silent! pclose!
"au FileType js set completeopt-=preview
"set completeopt-=preview " look into setting this by filetype
"autocmd FileType js set completeopt-=preview "look into setting this by filetype
let g:deoplete#sources#go#gocode_binary = $GOPATH.'/bin/gocode'
let g:deoplete#sources#go#use_cache = 1
let g:deoplete#sources#go#json_directory = '~/.nvim/deoplete/go/$GOOS_$GOARCH'
let g:deoplete#sources#go#source_importer = 1

" C++
let g:clang_library_path='/usr/local/Cellar/llvm/6.0.0/lib/libclang.dylib'

" autoclose html tags
iabbrev </ </<C-X><C-O>

map <silent> \e :NERDTreeToggle<CR>
map <silent> \E :NERDTreeFind<CR>

nmap <silent> \t :TagbarToggle<CR>

" dutyl
autocmd FileType d :DUDCDstartServer
autocmd VimLeave * silent! :DUDCDstopServer
let g:dutyl_stdImportPaths=['/usr/local/Cellar/dmd/2.067.0/include']

" scratch
let g:scratch_insert_autohide = 0
" to change default mappings, turn mapping off and set manually
let g:scratch_no_mappings = 1
let g:scratch_persistence_file = '~/.nvim/scratch'
nmap gs <Plug>(scratch-insert-reuse)
xmap gs <Plug>(scratch-selection-reuse)
nmap gS :ScratchPreview<CR>

" vim-json
let g:vim_json_syntax_conceal = 0

" remap split switching
map <tab> <c-w>
map <tab><tab> <c-w><c-w>

" tmux integrations
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
nnoremap <silent> <c-l> :TmuxNavigateRight<cr>
nnoremap <silent> <c-\> :TmuxNavigatePrevious<cr>
if exists('$TMUX')
	autocmd BufReadPost,FileReadPost,BufNewFile,BufEnter * call system("tmux rename-window " . expand("%:t"))
    autocmd VimLeave * call system("tmux setw automatic-rename")
endif

" copy clipboard in between "" or '
nmap <leader>" i"<Esc>p
nmap <leader>' i'<Esc>p

" https://github.com/neovim/neovim/issues/2528#issuecomment-239993819
hi Normal ctermbg=NONE

" go-vim stuff
"let g:neomake_go_enabled_makers = ['']
"let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck'] " remove golint fromt the defaults
let g:ale_go_gometalinter_options = '
  \ --aggregate
  \ --sort=line
  \ --vendor
  \ --vendored-linters
  \ --disable=gas
  \ --disable=goconst
  \ --disable=gocyclo
  \ '
  " \ --severity=errcheck:warning
  " \ --fast
let g:ale_linters = {'go': ['gometalinter']}
" let g:go_metalinter_deadline = "5s"
let g:go_fmt_fail_silently = 1
" let g:go_metalinter_enabled = [
"       \ 'deadcode', 'errcheck', 'gas', 'goconst', 'golint', 'gosimple',
"       \ 'gotype', 'ineffassign', 'interfacer', 'staticcheck', 'structcheck',
"       \ 'unconvert', 'varcheck', 'vet', 'vetshadow',
"       \ ]
let g:go_metalinter_enabled = [
      \ 'deadcode', 'errcheck', 'gas', 'goconst', 'golint', 'gosimple',
      \ 'ineffassign', 'interfacer', 'staticcheck', 'structcheck',
      \ 'unconvert', 'varcheck', 'vet', 'vetshadow',
      \ ]
let g:go_fmt_command = "goimports" " swap gofmt for goimports so that imports are autocleaned

let g:go_highlight_build_constraints = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
"let g:go_highlight_operators = 1
"let g:go_highlight_types = 1
let g:go_highlight_structs = 1
"let g:go_auto_sameids = 1

" rust
let g:rustfmt_autosave = 1
" set hidden
let g:racer_cmd = "/Users/ehdensinai/.cargo/bin/racer"
let g:deoplete#sources#rust#racer_binary='/Users/ehdensinai/.cargo/bin/racer'
let g:deoplete#sources#rust#rust_source_path='/Users/ehdensinai/.cargo/registry/src'

function! WordFrequency() range
  let all = split(join(getline(a:firstline, a:lastline)), '\A\+')
  let frequencies = {}
  for word in all
    let frequencies[word] = get(frequencies, word, 0) + 1
  endfor
  new
  setlocal buftype=nofile bufhidden=hide noswapfile tabstop=20
  for [key,value] in items(frequencies)
    call append('$', key."\t".value)
  endfor
  sort i
endfunction
command! -range=% WordFrequency <line1>,<line2>call WordFrequency()

" Sorts numbers in ascending order.
" Examples:
" [2, 3, 1, 11, 2] --> [1, 2, 2, 3, 11]
" ['2', '1', '10','-1'] --> [-1, 1, 2, 10]
function! Sorted(list)
  " Make sure the list consists of numbers (and not strings)
  " This also ensures that the original list is not modified
  let nrs = ToNrs(a:list)
  let sortedList = sort(nrs, "NaturalOrder")
  echo sortedList
  return sortedList
endfunction

" Comparator function for natural ordering of numbers
function! NaturalOrder(firstNr, secondNr)
  if a:firstNr < a:secondNr
    return -1
  elseif a:firstNr > a:secondNr
    return 1
  else
    return 0
  endif
endfunction

" Coerces every element of a list to a number. Returns a new list without
" modifying the original list.
function! ToNrs(list)
  let nrs = []
  for elem in a:list
    let nr = 0 + elem
    call add(nrs, nr)
  endfor
  return nrs
endfunction

function! WordFrequencySorted() range
  " Words are separated by whitespace or punctuation characters
  let wordSeparators = '[[:blank:][:punct:]]\+'
  let allWords = split(join(getline(a:firstline, a:lastline)), wordSeparators)
  let wordToCount = {}
  for word in allWords
    let wordToCount[word] = get(wordToCount, word, 0) + 1
  endfor

  let countToWords = {}
  for [word,cnt] in items(wordToCount)
    let words = get(countToWords,cnt,"")
    " Append this word to the other words that occur as many times in the text
    let countToWords[cnt] = words . " " . word
  endfor

  " Create a new buffer to show the results in
  new
  setlocal buftype=nofile bufhidden=hide noswapfile tabstop=20

  " List of word counts in ascending order
  let sortedWordCounts = Sorted(keys(countToWords))

  call append("$", "count \t words")
  call append("$", "--------------------------")
  " Show the most frequent words first -> Descending order
  for cnt in reverse(sortedWordCounts)
    let words = countToWords[cnt]
    call append("$", cnt . "\t" . words)
  endfor
endfunction

command! -range=% WordFrequencySorted <line1>,<line2>call WordFrequencySorted()
