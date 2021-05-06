{ config, pkgs, ... }:

let
  # set channel channel to nixpkgs-unstable
  nixpkgs = import <nixpkgs> {};
in
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.03";

  # Allow installation of propietary of "unfree" packages. Needed for parts of
  # mozilla overlay.
  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.overlays = [ (import "${mozilla-overlays}") ];

  home.packages = [
    nixpkgs.git
    nixpkgs.bat
    nixpkgs.exa
    nixpkgs.fd
    nixpkgs.graphviz
    nixpkgs.jq
    nixpkgs.starship
    nixpkgs.tokei
    nixpkgs.fd
    nixpkgs.modd
    nixpkgs.automake
    nixpkgs.autoconf
    nixpkgs.hugo
    nixpkgs.ffmpeg-full
    nixpkgs.age
    nixpkgs.silver-searcher
    nixpkgs.zlib
    nixpkgs.llvm_10
    nixpkgs.lldb_10
    nixpkgs.libwebp

    nixpkgs.delve
    nixpkgs.protobuf

    # nixpkgs.coreutils-full

    nixpkgs.python
    nixpkgs.python3

    nixpkgs.lua5_3

    # rust. eventually, see about using
    # https://github.com/mozilla/nixpkgs-mozilla
    # rustup manages rustc, cargo, etc. perhaps it
    # should also manage rust-analyzer?
    nixpkgs.rustup
    nixpkgs.rust-analyzer
    # pkgs.cargo
    # pkgs.rustfmt

    # nix language server
    nixpkgs.rnix-lsp

    nixpkgs.golangci-lint
  ];

  programs.zsh = import ./zsh-conf.nix { pkgs = nixpkgs; };
  programs.tmux = import ./tmux-conf.nix { pkgs = nixpkgs; };

  programs.neovim = {
    enable = true;
    package = nixpkgs.neovim-unwrapped;

    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;

    # plugins = with nixpkgs; [
    #   vimPlugins.gruvbox
    # ];

    # extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.vim";
    extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.templ.vim";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;

    defaultCommand = "fd";
    fileWidgetCommand = "fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "fd --type d --hidden --exclude '.git' --follow";
  };

  # programs.go = {
  #   enable = true;
  #   goPath = "${builtins.getEnv "HOME"}/gopath";
  #   goBin = "${builtins.getEnv "HOME"}/gobin";
  # };
}
