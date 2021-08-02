require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  -- ignore_install = { "go" }, -- List of parsers to ignore installing
  highlight = {
    enable = true,              -- false will disable the whole extension
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gn",
      node_incremental = "gn",
      scope_incremental = "g,",
      node_decremental = "gm",
    },
  },
}
