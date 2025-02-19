{ pkgs }:
{
  enable = true;

  # set EDITOR
  defaultEditor = true;

  vimdiffAlias = true;
  vimAlias = true;

  withNodeJs = false;
  withPython3 = false;
  withRuby = false;

  extraLuaConfig = builtins.readFile ./config/init.lua;

  extraPackages = with pkgs; [
    ripgrep # used by fzf
    fd # fzf
    bat # fzf
    git # fugitive, nvim-tree, lualine, fzf, etc
    nodejs # copilot

    bash-language-server
    lua-language-server
    nil
    nixpkgs-fmt
    nodePackages.typescript-language-server
    rust-analyzer
    vscode-langservers-extracted
    yaml-language-server
    zls
  ];

  plugins = with pkgs.vimPlugins; [
    {
      plugin = copilot-lua;
      type = "lua";
      config = builtins.readFile ./config/plugins/copilot.lua;
    }
    {
      plugin = copilot-cmp;
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

    nvim-web-devicons
    {
      plugin = gruvbox-nvim;
      type = "lua";
      config = ''
        -- setup must be called before loading the colorscheme
        -- Default options:
        require("gruvbox").setup({
          undercurl = false,
          underline = true,
          bold = true,
          italic = {
            strings = false,
            comments = false,
            operators = false,
            folds = true,
          },
          strikethrough = false,
          invert_selection = false,
          invert_signs = false,
          invert_tabline = false,
          invert_intend_guides = false,
          inverse = true, -- invert background for search, diffs, statuslines and errors
          contrast = "hard", -- can be "hard", "soft" or empty string
          palette_overrides = {},
          overrides = {},
          dim_inactive = false,
          transparent_mode = false,
        })

        -- setup must be called before loading
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
    editorconfig-vim
    vim-toml
    vim-markdown
    rust-vim
    vim-javascript

    {
      # https://nixos.org/manual/nixpkgs/unstable/#vim
      # plugin = nvim-treesitter.withAllGrammars;
      plugin = (nvim-treesitter.withPlugins (
        plugins: with plugins; [
          tree-sitter-bash
          tree-sitter-dockerfile
          tree-sitter-go
          tree-sitter-java
          tree-sitter-jq
          tree-sitter-json
          tree-sitter-lua
          tree-sitter-make
          tree-sitter-nix
          tree-sitter-python
          tree-sitter-regex
          tree-sitter-rust
          tree-sitter-toml
          tree-sitter-yaml
          tree-sitter-zig
          tree-sitter-javascript
          tree-sitter-ruby
          tree-sitter-typescript
          tree-sitter-vim
          tree-sitter-vimdoc
          tree-sitter-comment
          tree-sitter-c
        ]
      ));
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
      config = builtins.readFile ./config/plugins/fzf.lua;
    }

    {
      plugin = luasnip;
      type = "lua";
      config = builtins.readFile ./config/plugins/luasnip.lua;
    }

    {
      plugin = pkgs.vimUtils.buildVimPlugin {
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
}
