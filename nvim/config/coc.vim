" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Documentation
nnoremap <silent> K :call <SID>show_documentation()<CR>
let g:go_doc_keywordprg_enabled = 0 " let coc handle this
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
" autocmd CursorHold * silent call CocActionAsync('highlight')

augroup mygroup
  autocmd!
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" autocmd FileType rust,javascript,go nmap <silent> gd <Plug>(coc-definition)
nmap <silent> <leader>ff :call CocAction('format')<CR>

" autocmd FileType html,javascript,css,typescript nmap <silent> <leader>ff :CocCommand prettier.formatFile<cr>
" nmap <silent> <leader>ff :CocCommand prettier.formatFile<cr>
