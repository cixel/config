{ pkgs }:
{
  enable = true;
  # package = pkgs.neovim-unwrapped;

  vimdiffAlias = true;
  withNodeJs = true;
  withPython3 = true;

  extraPackages = with pkgs; [
    fd # used by fzf
    rnix-lsp
    rust-analyzer
    nodePackages.typescript-language-server
  ];

  plugins = with pkgs.vimPlugins; [
    {
      plugin = gruvbox;
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/looks.vim";
    }
    {
      plugin = nerdtree;
      config = ''
        map <silent> \e :NERDTreeToggle<CR>
        map <silent> \E :NERDTreeFind<CR>
        let NERDTreeShowHidden=1
      '';
    }
    nerdcommenter

    {
      plugin = vim-airline;
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/airline.vim";
    }
    vim-airline-themes


    fugitive
    vim-sensible
    vim-surround
    vim-repeat
    vim-endwise
    vim-commentary

    tabular
    {
      plugin = vim-tmux-navigator;
      config = ''
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
      '';
    }

    {
      plugin = ale;
      config = ''
        nmap <silent> <C-Q> <Plug>(ale_previous_wrap)
        nmap <silent> <C-q> <Plug>(ale_next_wrap)
        let g:ale_sign_error = 'E'
        let g:ale_sign_warning = 'W'
        let g:ale_sign_style_warning = 'WS'
        let g:ale_sign_style_error = 'WS'
        let g:ale_list_window_size = 7
        let g:ale_echo_msg_format = '%s (%linter%%:code%)'
        let g:ale_linters_explicit = 1

        " weird because there's no guarantee these exist.
        let g:ale_linters = {
        \   'go': ['vet', 'golint'],
        \}
      '';
    }
    {
      plugin = nvim-ale-diagnostic;
      config = "lua require(\"nvim-ale-diagnostic\")";
    }
    {
     plugin = nvim-lspconfig;
      config = "lua << EOF\n"
      + builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/lsp.lua"
      + "\nEOF";
    }
    {
      plugin = lspsaga-nvim;
      config = "lua << EOF\n"
      + builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-compe.lua"
      + "\nEOF";
    }

    # {
    #   plugin = completion-nvim;
    #   config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/completion-nvim.vim";
    # }
    # completion-tabnine
    {
      plugin = nvim-compe;
      config = "lua << EOF\n"
      + builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-compe.lua"
      + "\nEOF";
    }
    compe-tabnine


    {
      plugin = vim-go;
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/go.vim";
    }
    {
      plugin = fzf-vim;
      config = ''
        " FZF.vim
        " let $FZF_DEFAULT_COMMAND = 'ag --hidden --ignore-dir={dist,target,node_modules,docs,rulepack/xml,experiments,code-coverage-report} --ignore .git -g ""'
        " set rtp+=/usr/local/opt/fzf " for fzf to load on start from the brew install
        " set rtp+= " for fzf to load on start from the brew install
        " let $FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git' -E 'target/**'"
        let $FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"
        nmap ; :FZF<CR>
      '';
    }

    {
      plugin = ultisnips;
      config = ''
        " may need to use this to prevent hm switch from clobbering snippets directory
        " let g:UltiSnipsSnippetDirectories = [home . '/.config/nixpkgs/extraConfigs/.vim/my-snippets']
        let g:UltiSnipsExpandTrigger="<c-q>"
        let g:UltiSnipsJumpForwardTrigger="<c-j>"
        let g:UltiSnipsJumpBackwardTrigger="<c-k>"
        let g:UltiSnipsEditSplit="vertical"
      '';
    }
  ];

  extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.templ.vim";
}
