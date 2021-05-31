" Use completion-nvim in every buffer
autocmd BufEnter * lua require'completion'.on_attach()

" possible value: 'UltiSnips', 'Neosnippet', 'vim-vsnip', 'snippets.nvim'
let g:completion_enable_snippet = 'UltiSnips'

imap <tab> <Plug>(completion_smart_tab)
imap <s-tab> <Plug>(completion_smart_s_tab)

" Use <Tab> and <S-Tab> to navigate through popup menu
" Disabling for now because of conflicts w/ supertab?
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c

" Just disabling for now because it's throwing lua errors
let g:completion_enable_auto_signature = 0
