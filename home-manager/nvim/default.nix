{ pkgs }:
{
  enable = true;
  package = pkgs.neovim-unwrapped;

  vimdiffAlias = true;
  withNodeJs = false;
  withPython3 = false;
  withRuby = false;

  extraPackages = with pkgs; [
    ripgrep # used by fzf
    fd # fzf
    git # fugitive, nvim-tree, lualine, fzf, etc

    rnix-lsp
    rust-analyzer
    nodePackages.typescript-language-server
    nodePackages.yaml-language-server
    lua-language-server
  ];

  plugins = with pkgs.vimPlugins; [
    {
      plugin = impatient-nvim;
      type = "lua";
      config = ''
        require('impatient')
        -- enable LuaCacheProfile to see profiling
        -- require('impatient').enable_profile()
      '';
    }

    {
      plugin = undotree;
      type = "lua";
      config = ''
        vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)
      '';
    }

    {
      plugin = gruvbox;
      type = "lua";
      config = ''
        vim.g['gruvbox_contrast_dark'] = 'hard'
        vim.cmd [[colorscheme gruvbox]]
      '';
    }

    {
      plugin = nvim-tree-lua;
      type = "lua";
      config = builtins.readFile ./config/plugins/nvim-tree.lua;
    }

    {
      plugin = lualine-nvim;
      type = "lua";
      config = builtins.readFile ./config/plugins/lualine.lua;
    }

    fugitive
    vim-surround
    {
      plugin = vim-matchup;
      type = "lua";
      config = ''
        -- don't load matchit by default, this is a full replacement
        vim.g.loaded_matchit = 1
      '';
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
      config = builtins.readFile ./config/treesitter.lua;
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
      type = "lua";
      config = builtins.readFile ./config/plugins/vim-tmux-navigator.lua;
    }

    {
      plugin = nvim-lspconfig;
      type = "lua";
      config = builtins.readFile ./config/lsp.lua;
    }
    {
      plugin = nvim-lint;
      type = "lua";
      config = builtins.readFile ./config/plugins/nvim-lint.lua;
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
      config = builtins.readFile ./config/plugins/nvim-cmp.lua;
    }
    # nvim-cmp config currently depends on nvim-autopairs existing and will
    # give lua errors if it doesn't. I should probably fix that. Also depends
    # on luasnip.
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
        ${builtins.readFile ./config/plugins/luasnip.lua}
      '';
    }

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
  ];

  extraLuaConfig = builtins.readFile ./config/init.lua;
}
