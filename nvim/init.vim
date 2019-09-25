call plug#begin()
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
Plug 'junegunn/fzf'
Plug 'LnL7/vim-nix'
" Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }

Plug 'editorconfig/editorconfig-vim'
" Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
" Plug 'zchee/deoplete-go', { 'do': 'make' }

Plug 'majutsushi/tagbar' " source code nav in sidebar
Plug 'dense-analysis/ale'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'alvan/vim-closetag'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/nerdcommenter'
Plug 'mtth/scratch.vim'
Plug 'SirVer/ultisnips'
Plug 'godlygeek/tabular'
" Plug 'Raimondi/delimitMate'
Plug 'christoomey/vim-tmux-navigator'
Plug 'cohama/lexima.vim' " not sure if I use this
Plug 'ervandew/supertab'
" Plug 'milkypostman/vim-togglelist' " toggle loclist and quickfix
Plug 'rhysd/vim-crystal' " support for crystal lang
" Plug 'leafgarland/typescript-vim'
Plug 'christianrondeau/vim-base64' " base64 encode/decode
Plug 'cespare/vim-toml'

Plug 'plasticboy/vim-markdown'

" C++
Plug 'rip-rip/clang_complete'

" Rust
Plug 'rust-lang/rust.vim'

" i don't really use these
" https://github.com/jceb/vim-orgmode/blob/master/doc/orgguide.txt
Plug 'jceb/vim-orgmode'
Plug 'tpope/vim-speeddating'

Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'chriskempson/base16-vim'
Plug 'iCyMind/NeoSolarized'
Plug 'morhetz/gruvbox'
Plug 'sonph/onehalf', { 'rtp': 'vim/' }

"Plug 'maksimr/vim-jsbeautify'
"Plug 'Chiel92/vim-autoformat'
Plug 'sbdchd/neoformat'

Plug 'tpope/vim-fugitive' " I should look into actually using this
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'vim-scripts/VisIncr'

" Plug 'elzr/vim-json'
" Plug 'othree/yajs.vim', { 'for': 'javascript' } " better syntax for javascript ** Very slow. Look into replacement
Plug 'pangloss/vim-javascript'
call plug#end()

source ~/.config/nvim/custom/looks.vim
source ~/.config/nvim/custom/go.vim
source ~/.config/nvim/custom/coc.vim
source ~/.config/nvim/custom/misc_funcs.vim

if exists('##TextYankPost')
	autocmd TextYankPost * silent! lua require'vim.highlight'.on_yank('Substitute', 200)
endif

set undodir=~/.vimdid
set undofile

syntax on
filetype plugin indent on
set hidden
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

autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType rust setlocal expandtab
autocmd FileType markdown setlocal textwidth=80 expandtab wrap spell


" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" set folding method to be language defined and files are not folded when
" opened
set foldmethod=syntax
set foldlevelstart=20
"set nofoldenable

let g:python_host_prog = '/usr/local/bin/python3'
let g:python3_host_prog = '/usr/local/bin/python3'


" yank to clipboard
set clipboard=unnamed

" do not require scratch/fileless buffers to be saved
set hidden


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
nmap <C-e> :e#<CR>

" next/previous buffer
nmap <C-n> :bnext<CR>
nmap <C-m> :bprev<CR>

" autocmd FileType rust,javascript,go nmap <silent> gd <Plug>(coc-definition)
nmap <silent> <leader>ff :call CocAction('format')<CR>

au BufNewFile,BufRead *.ejs set filetype=html
" autocmd FileType html,javascript,css,typescript nmap <silent> <leader>ff :CocCommand prettier.formatFile<cr>
" nmap <silent> <leader>ff :CocCommand prettier.formatFile<cr>

"nmap <leader>.. :lclose<CR>
nmap <script> <silent> <leader>.. :call ToggleLocationList()<CR>

" ale
nmap <silent> <C-Q> <Plug>(ale_previous_wrap)
nmap <silent> <C-q> <Plug>(ale_next_wrap)
" Only run linters named in ale_linters settings.
let g:ale_linters_explicit = 1

" FZF.vim
" let $FZF_DEFAULT_COMMAND = 'ag --hidden --ignore-dir={dist,target,node_modules,docs,rulepack/xml,experiments,code-coverage-report} --ignore .git -g ""'
" set rtp+=/usr/local/opt/fzf " for fzf to load on start from the brew install
" set rtp+= " for fzf to load on start from the brew install
" let $FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git' -E 'target/**'"
let $FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"
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
" let g:deoplete#enable_at_startup = 1
"let g:tern_show_signature_in_pum = '0'
"autocmd CompleteDone * silent! pclose! *.js

" autocmd CompleteDone * silent! pclose!

"au FileType js set completeopt-=preview
" set completeopt-=preview " look into setting this by filetype
"autocmd FileType js set completeopt-=preview "look into setting this by filetype

" C++
let g:clang_library_path='/usr/local/Cellar/llvm/6.0.0/lib/libclang.dylib'

" autoclose html tags
iabbrev </ </<C-X><C-O>

map <silent> \e :NERDTreeToggle<CR>
map <silent> \E :NERDTreeFind<CR>
let NERDTreeShowHidden=1

nmap <silent> \t :TagbarToggle<CR>

" scratch
let g:scratch_insert_autohide = 0
" to change default mappings, turn mapping off and set manually
let g:scratch_no_mappings = 1
let g:scratch_persistence_file = '~/.nvim/scratch'
" nmap gs <Plug>(scratch-insert-reuse)
" xmap gs <Plug>(scratch-selection-reuse)
" nmap gS :ScratchPreview<CR>

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

" rust
" let g:rustfmt_autosave = 1
