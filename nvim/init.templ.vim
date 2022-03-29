source ~/.config/nvim/config/quickload.vim

augroup highlight_yank
	autocmd!
	" type :hi to see other higroup options
	au TextYankPost * silent! lua vim.highlight.on_yank { higroup='IncSearch', timeout=150 }
augroup END

set undodir=~/.vimdid
set undofile

" syntax on
syntax off
filetype plugin indent on
set hidden
let mapleader=","


" Potential performance improvemenets (scrolling)
set noshowcmd
set lazyredraw

autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType rust setlocal expandtab
autocmd FileType markdown setlocal textwidth=80 expandtab wrap spell
autocmd FileType proto setlocal ts=2 expandtab

" set so files are not folded when vim starts
set foldlevelstart=99
" folding with treesitter
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()
"set nofoldenable

" yank to clipboard
set clipboard=unnamed

" do not require scratch/fileless buffers to be saved
set hidden

" indentation settings for using hard tabs for indent. Display tabs as
" four characters wide.
set shiftwidth=4
set tabstop=4

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

" https://github.com/neovim/neovim/issues/416 changed the default for Y to y$,
" which is admittedly more sensible but my fingers refuse. double tapping y
" feels worse/slower than shift-y just because of where y is
map Y yy

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

" autoclose html tags
iabbrev </ </<C-X><C-O>

" remap split switching
map <tab> <c-w>
" map <tab><tab> <c-w><c-w>

" copy clipboard in between "" or '
nmap <leader>" i"<Esc>p
nmap <leader>' i'<Esc>p

"
" misc funcs
"
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
