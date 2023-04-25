{ pkgs }:
{
  enable = true;
  package = pkgs.neovim-unwrapped;

  vimdiffAlias = true;
  withNodeJs = false;
  withPython3 = false;
  withRuby = false;

  extraPackages = with pkgs; [
    ripgrep # used by telescope/fzf
    fd # used by fzf

    rnix-lsp
    rust-analyzer
    nodePackages.typescript-language-server
    nodePackages.yaml-language-server
    lua-language-server

    # treesitter README lists these as requirements
    git
    zig
  ];

  plugins = with pkgs.vimPlugins; [
    {
      plugin = gruvbox;
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/looks.vim";
      # config = builtins.readFile "./nvim/config/looks.vim";
    }

    {
      plugin = nvim-tree-lua;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-tree.lua";
    }

    {
      plugin = lualine-nvim;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/lualine.lua";
    }

    fugitive
    vim-sensible
    vim-surround

    # vim-matchup
    # this got super slow on this update:
    # https://github.com/NixOS/nixpkgs/commit/685117273d1e1a41e27c73df0805ca08f38c0fbd
    # so, hardcode the previous version for a bit
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "vim-matchup";
        version = "2021-02-20";
        src = pkgs.fetchFromGitHub {
          owner = "andymass";
          repo = "vim-matchup";
          rev = "1364b2ba551c82fdb342b646da666a477490c063";
          sha256 = "sha256-Ktm8b2HMmYw7xaINWu0gjYD2DY4B7LYl4wj2V1K4Frs=";
        };
        meta.homepage = "https://github.com/christianrondeau/vim-base64";
      };
    }

    vim-repeat
    # endwise seems to interfere with nvim-autopairs at the moment, although
    # the readme does have information about making it work with endwise
    # vim-endwise
    {
      plugin = comment-nvim;
      type = "lua";
      config = ''
        -- i prefer .txt comments because of testscript txt files
        require('Comment.ft').set('text', '# %s')
        require('Comment').setup()
      '';
    }
    tabular
    editorconfig-vim
    vim-toml
    vim-markdown
    rust-vim
    vim-javascript

    {
      # https://nixos.org/manual/nixpkgs/unstable/#vim
      plugin = nvim-treesitter.withAllGrammars;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/treesitter.lua";
    }
    nvim-treesitter-textobjects
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "nvim-treesitter-playground";
        version = "2022-04-25";
        src = pkgs.fetchFromGitHub {
          owner = "nvim-treesitter";
          repo = "playground";
          rev = "13e2d2d63ce7bc5d875e8bdf89cb070bc8cc7a00";
          sha256 = "1klkg3n3rymb6b9im7hq9yq26mqf2v79snsqbx72am649c6qc0ns";
        };
        meta.homepage = "https://github.com/nvim-treesitter/playground";
      };
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
      plugin = nvim-lspconfig;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/lsp.lua";
    }
    {
      plugin = nvim-autopairs;
      type = "lua";
      config = ''
        require('nvim-autopairs').setup({
          check_ts = true, -- check treesitter
          disable_in_macro = true,
        })
      '';
    }
    {
      plugin = nvim-lint;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-lint.lua";
    }

    lspkind-nvim
    cmp-buffer
    cmp-nvim-lsp
    cmp-nvim-lua
    cmp-path
    cmp_luasnip
    cmp-nvim-lsp-signature-help
    cmp-nvim-lsp-document-symbol
    {
      plugin = nvim-cmp;
      type = "lua";
      config = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/nvim-cmp.lua";
    }

    vim-nix

    {
      plugin = fzf-vim;
      type = "lua";
      config = ''
        vim.env.FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"

        vim.keymap.set('n', ';',         '<cmd>FZF<CR>', { silent = true })
        vim.keymap.set('n', '<leader>g', '<cmd>Rg<CR>', { silent = true })
        vim.keymap.set('n', '<leader>c', '<cmd>Commits<CR>', { silent = true })
        vim.keymap.set('n', '<leader>x', '<cmd>BCommits<CR>', { silent = true })
      '';
    }

    {
      plugin = luasnip;
      type = "lua";
      config = ''
        ${builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/config/plugins/luasnip.lua"}
        -- re-enable if i ever want to use the premade snippets from friendly-snippets
        -- for some reason, lazy_load isn't working
        -- require("luasnip/loaders/from_vscode").load({ paths = "${friendly-snippets}/share/vim-plugins/friendly-snippets/" })
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
