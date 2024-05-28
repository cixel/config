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
    nodejs # copilot

    nil
    rust-analyzer
    nodePackages.typescript-language-server
    nodePackages.yaml-language-server
    lua-language-server
    vscode-langservers-extracted
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

    # note for upgrading these: for some reason, I get an SSL error (netskope
    # related) when I completely replace the hash with AAA[...]. I don't get
    # the same issue if I only replace a single character with `0` to
    # invalidate the hash.
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "copilot.lua";
        version = "rev";
        src = pkgs.fetchFromGitHub {
          owner = "zbirenbaum";
          repo = "copilot.lua";
          rev = "50ca36fd766db4d444094de81f5e131b6628f48f";
          sha256 = "sha256-9AU2x0Yvw66FbLmI4QDTnx9nQFZpXlT4EUxq+3b6ucI=";
        };
        meta.homepage = "https://github.com/zbirenbaum/copilot.lua";
      };
      type = "lua";
      config = builtins.readFile ./config/plugins/copilot.lua;
    }
    {
      plugin = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "copilot-cmp";
        version = "rev";
        src = pkgs.fetchFromGitHub {
          owner = "zbirenbaum";
          repo = "copilot-cmp";
          rev = "d631b3afbf26bb17d6cf2b3cd8f3d79e7d5eeca1";
          sha256 = "sha256-OUWcwJqKA4r34S3biY7zd66uCLkeuGAGC6KRm6JLWqQ=";
        };
        meta.homepage = "https://github.com/zbirenbaum/copilot.lua";
      };
      type = "lua";
      config = ''
        require("copilot_cmp").setup()
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
      plugin = oil-nvim;
      type = "lua";
      config = ''
      require("oil").setup {
        view_options = {
          show_hidden = true,
        };
      }

      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
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
