{ pkgs }:
{
  enable = true;
  package = pkgs.neovim-unwrapped;

  vimdiffAlias = true;
  withNodeJs = false;
  withPython3 = false;
  withRuby = false;

  extraPackages = with pkgs; [
    fd # used by fzf
    rnix-lsp
    rust-analyzer
    nodePackages.typescript-language-server
    git # treesitter README lists this as a requirement
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
      plugin = lualine-nvim;
      config = ''
        lua << EOF
        ${builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/lualine.lua"}
        EOF
      '';
    }

    fugitive
    vim-sensible
    vim-surround
    vim-repeat
    # endwise seems to interfere with nvim-autopairs at the moment, although
    # the readme does have information about making it work with endwise
    # vim-endwise
    vim-commentary
    tabular
    editorconfig-vim
    vim-toml
    vim-markdown
    rust-vim
    vim-javascript

    {
      plugin = nvim-treesitter;
      config = "lua << EOF\n"
      + builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/treesitter.lua"
      + "\nEOF";
    }

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
      plugin = nvim-compe;
      config = ''
        "inoremap <silent><expr> <CR>      compe#confirm('<CR>')
        inoremap <silent><expr> <C-Space> compe#complete()
        "inoremap <silent><expr> <CR>      compe#confirm(lexima#expand('<LT>CR>', 'i'))
        inoremap <silent><expr> <C-e>     compe#close('<C-e>')
      ''
      + "lua << EOF\n"
      + builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-compe.lua"
      + "\nEOF";
    }
    {
      plugin = nvim-autopairs;
      config = ''
        lua << EOF
        require('nvim-autopairs').setup()
        require('nvim-autopairs.completion.compe').setup({
          check_ts = true, -- check treesitter

          map_cr = true, --  map <CR> on insert mode
          map_complete = true -- it will auto insert `(` after select function or method item
        })
        EOF
      '';
    }

    # compe-tabnine


    vim-nix
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
      plugin = luasnip;
      config = ''
        lua << EOF
        ${builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/luasnip.lua"}
        -- re-enable if i ever want to use the premade snippets from friendly-snippets
        -- for some reason, lazy_load isn't working
        -- require("luasnip/loaders/from_vscode").load({ paths = "${friendly-snippets}/share/vim-plugins/friendly-snippets/" })
        EOF
      '';
    }
    #     let g:UltiSnipsExpandTrigger="<c-q>"
    #     let g:UltiSnipsJumpForwardTrigger="<c-j>"
    #     let g:UltiSnipsJumpBackwardTrigger="<c-k>"
    #     let g:UltiSnipsEditSplit="vertical"

    # see about upstreaming these... esp scratch.vim since it has the most starts
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "visincr";
        version = "2011-08-18";
        src = pkgs.fetchFromGitHub {
          owner = "vim-scripts";
          repo = "VisIncr";
          rev = "13e8538cf332fd131ebb60422b4a01d69078794b";
          sha256 = "1qfw3r6rp67nz0mrn603mm8knljm9ld9llra1nxyz54hs8xmhqfs";
        };
        meta.homepage = "https://github.com/vim-scripts/VisIncr";
      };
    }
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "vim-base64";
        version = "2021-02-20";
        src = pkgs.fetchFromGitHub {
          owner = "christianrondeau";
          repo = "vim-base64";
          rev = "d15253105f6a329cd0632bf9dcbf2591fb5944b8";
          sha256 = "0im33dwmjjbd6lm2510lf7lyavza17lsl119cqjjdi9jdsrh5bbg";
        };
        meta.homepage = "https://github.com/christianrondeau/vim-base64";
      };
      config = ''
        " Visual Mode mappings
        vnoremap <silent> <leader>B c<c-r>=base64#decode(@")<cr><esc>`[v`]h
        vnoremap <silent> <leader>b c<c-r>=base64#encode(@")<cr><esc>`[v`]h

        " Regex mappings
        nnoremap <leader>b/ :%s/\v()/\=base64#encode(submatch(1))/<home><right><right><right><right><right><right>
        nnoremap <leader>B/ :%s/\v()/\=base64#decode(submatch(1))/<home><right><right><right><right><right><right>
      '';
    }
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "scratch-vim";
        version = "2021-05-03";
        src = pkgs.fetchFromGitHub {
          owner = "mtth";
          repo = "scratch.vim";
          rev = "adf826b1ac067cdb4168cb6066431cff3a2d37a3";
          sha256 = "0gy3n1sqxmqya7xv9cb5k2y8jagvzkaz6205yjzcp44wj8qsxi1z";
        };
        meta.homepage = "https://github.com/mtth/scratch.vim";
      };
      config = ''
        let g:scratch_insert_autohide = 0
        " to change default mappings, turn mapping off and set manually
        let g:scratch_no_mappings = 1
        let g:scratch_persistence_file = '~/.nvim/scratch'
        " nmap gs <Plug>(scratch-insert-reuse)
        " xmap gs <Plug>(scratch-selection-reuse)
        " nmap gS :ScratchPreview<CR>
      '';
    }
  ];

  extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.templ.vim";
}
