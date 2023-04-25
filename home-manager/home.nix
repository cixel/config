{ config, pkgs, lib, ... }:

let
  # set channel channel to nixpkgs-unstable
  # pkgs = import <nixpkgs> {
  #   overlays = [
  #     # https://github.com/NixOS/nixpkgs/issues/168984
  #     (self: super: {
  #       golangci-lint = super.golangci-lint.override {
  #         buildGoModule = super.buildGoModule;
  #       };
  #     })
  #   ];
  # };

  contrast-detect-secrets = pkgs.python3Packages.callPackage ./detect-secrets.nix { };

  inherit (pkgs.stdenv) isLinux isDarwin;
  # https://github.com/nix-community/neovim-nightly-overlay
in
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.toPath (builtins.getEnv "HOME");

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  nixpkgs.overlays = [
    # (import (builtins.fetchTarball {
    #   url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
    # }))
    (self: super: {
      # fsync on darwin is broken in that it's not a true fsync, so go's
      # syscall wrapper calls F_FULLFSYNC instead to make sure that writes are
      # actually flushed as expected. In general, with a laptop, there's probably
      # no issue, because the battery controler should handle flushing cache when
      # there's a sudden power loss or something. Down the rabbit hole of tweets is
      # more justification on this. This patch changes it to just call fsync. I
      # never use darwin besides on a laptop, so it should be safe enough for me.
      #
      # https://github.com/golang/go/issues/28739
      go = super.go_1_20.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ (
          if lib.stdenv.isDarwin then [ ./fd_fsync_darwin.patch ]
          else [ ]
        );
      });
    })
  ];

  home.packages = with pkgs; [
    git
    curl
    ripgrep
    bat # cat alternative
    exa # ls alternative
    # glances # top alternative
    hyperfine # benchmarking
    fd
    graphviz
    jq
    tokei
    # hugo
    age
    silver-searcher
    zig
    python3
    luajit
    # rust. eventually, see about using
    # https://github.com/mozilla/pkgs-mozilla
    # rustup manages rustc, cargo, etc. perhaps it
    # should also manage rust-analyzer?
    rustup

    # this won't be useable as a server because it's only available to a single
    # user.
    mosh

    golangci-lint

    # i use these for work and prefer having them already loaded to avoid
    # needing to enter a nix shell for random build dependencies
    contrast-detect-secrets
    xz
  ];

  programs.neovim = import ./nvim-conf.nix { inherit pkgs; };
  programs.starship = import ./starship-conf.nix { inherit pkgs lib; };
  programs.tmux = import ./tmux-conf.nix { inherit pkgs; };
  programs.zsh = import ./zsh-conf.nix { inherit pkgs; };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;

    defaultCommand = "fd";
    fileWidgetCommand = "fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "fd --type d --hidden --exclude '.git' --follow";
  };

  programs.go = {
    enable = true;
    package = pkgs.go_1_20;
    goPath = "${builtins.getEnv "HOME"}/gopath";
    goBin = "${builtins.getEnv "HOME"}/gobin";
  };
}
