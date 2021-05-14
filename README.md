Uses [nix home-manager](https://github.com/rycee/home-manager) to generate configs.

TODO:

* would be nice to have nix track nvim plugins for rollbacks. I don't want it
  to manage it entirely, because I like the update frequency I get with
  :PlugUpdate (especially for vim-go), but it means nix rollbacks won't do
  anything for nvim.
