" Use completion-nvim in every buffer
autocmd BufEnter * lua require'completion'.on_attach()

let g:completion_chain_complete_list = {
	\'default' : [
	\    {'complete_items': ['lsp', 'snippet', 'tabnine']},
	\    {'complete_items': ['path'], 'triggered_only': ['/']},
	\    {'mode': '<c-p>'},
	\    {'mode': '<c-n>'}
	\]
	\}


" possible value: 'UltiSnips', 'Neosnippet', 'vim-vsnip', 'snippets.nvim'
let g:completion_enable_snippet = 'UltiSnips'

imap <tab> <Plug>(completion_smart_tab)
imap <s-tab> <Plug>(completion_smart_s_tab)

" Use <Tab> and <S-Tab> to navigate through popup menu
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c

" If the confirm key has a fallback mapping, for example when using the
" auto pairs plugin, it maps to `<cr>`. You can avoid using the default
" confirm key option and use a mapping like this instead:
let g:completion_confirm_key = ""
imap <expr> <cr>  pumvisible() ? complete_info()["selected"] != "-1" ?
		\ "\<Plug>(completion_confirm_completion)"  :
		\ "\<c-e>\<CR>" : "\<CR>"


" Just disabling for now because it's throwing lua errors
let g:completion_enable_auto_signature = 0

let g:completion_matching_strategy_list = ['exact', 'substring', 'fuzzy']

let g:completion_trigger_on_delete = 1
