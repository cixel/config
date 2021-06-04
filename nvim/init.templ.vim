" XXX it looks like I can PlugSnapshot to generate a file which captures the
" current plugin state. I may be able to generate one, commit it, add it as a
" dependency in my nix conf.
call plug#begin('~/.config/nvim/plugged')
Plug 'LnL7/vim-nix'
Plug 'editorconfig/editorconfig-vim'
Plug 'majutsushi/tagbar' " source code nav in sidebar
Plug 'mtth/scratch.vim'
Plug 'cohama/lexima.vim' " adds auto-closing; not sure how this interacts with tpop/vim-endwise
Plug 'rhysd/vim-crystal' " support for crystal lang
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
" Plug 'morhetz/gruvbox'
Plug 'sonph/onehalf', { 'rtp': 'vim/' }

"Plug 'maksimr/vim-jsbeautify'
"Plug 'Chiel92/vim-autoformat'
Plug 'sbdchd/neoformat'

" Plug 'tpope/vim-fugitive' " I should look into actually using this
" Plug 'tpope/vim-sensible'
" Plug 'tpope/vim-commentary'
" Plug 'tpope/vim-surround'
" Plug 'tpope/vim-repeat'
" Plug 'tpope/vim-endwise'
Plug 'vim-scripts/VisIncr'
Plug 'machakann/vim-highlightedyank'
Plug 'SirVer/ultisnips'

" Plug 'elzr/vim-json'
" Plug 'othree/yajs.vim', { 'for': 'javascript' } " better syntax for javascript ** Very slow. Look into replacement
Plug 'pangloss/vim-javascript'
call plug#end()

" source ~/.config/nvim/config/looks.vim
" source ~/.config/nvim/config/go.vim
source ~/.config/nvim/config/misc_funcs.vim
luafile ~/.config/nvim/config/lsp.lua
" source ~/.config/nvim/config/coc.vim

" XXX for vim-highlightedyank, can delete this on newer versions of neovim
" if !exists('##TextYankPost')
"   map y <Plug>(highlightedyank)
" endif
let g:highlightedyank_highlight_duration = 200

set undodir=~/.vimdid
set undofile

syntax on
filetype plugin indent on
set hidden
let mapleader=","

" Potential performance improvemenets (scrolling)
set noshowcmd
" set nolazyredraw

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
autocmd FileType proto setlocal ts=4 expandtab


" set folding method to be language defined and files are not folded when
" opened
set foldmethod=syntax
set foldlevelstart=20
"set nofoldenable

" XXX don't set these to let home-manager set these to the correct paths
" let g:python_host_prog = '/usr/local/bin/python3'
" let g:python3_host_prog = '~/.nix-profile/bin/python3'


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


au BufNewFile,BufRead *.ejs set filetype=html

"nmap <leader>.. :lclose<CR>
nmap <script> <silent> <leader>.. :call ToggleLocationList()<CR>

" Trigger configuration. Do not use <tab>
let g:UltiSnipsExpandTrigger="<c-q>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"
let g:SuperTabDefaultCompletionType = "<c-tab>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" C++
let g:clang_library_path='/usr/local/Cellar/llvm/6.0.0/lib/libclang.dylib'

" autoclose html tags
iabbrev </ </<C-X><C-O>

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

" copy clipboard in between "" or '
nmap <leader>" i"<Esc>p
nmap <leader>' i'<Esc>p

" https://github.com/neovim/neovim/issues/2528#issuecomment-239993819
" hi Normal ctermbg=NONE

" rust
" let g:rustfmt_autosave = 1
