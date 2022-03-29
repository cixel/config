{ config, pkgs, lib, ... }:

let
  # set channel channel to nixpkgs-unstable
  pkgs = import <nixpkgs> { };
  contrast-detect-secrets = pkgs.python3Packages.callPackage ./detect-secrets.nix { };
  # https://github.com/nix-community/neovim-nightly-overlay
in
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # home.username = "$USER";
  # home.homeDirectory = builtins.toPath "$HOME";

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
  # nixpkgs.overlays = [
  #   (import (builtins.fetchTarball {
  #     url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
  #   }))
  # ];

  # fsync on darwin is broken in that it's not a true fsync, so go's
  # syscall wrapper calls F_FULLFSYNC instead to make sure that writes are
  # actually flushed as expected. In general, with a laptop, there's probably
  # no issue, because the battery controler should handle flushing cache when
  # there's a sudden power loss or something. Down the rabbit hole of tweets is
  # more justification on this. This patch changes it to just call fsync. I
  # never use darwin besides on a laptop, so it should be safe enough for me.
  #
  # https://github.com/golang/go/issues/28739
  nixpkgs.overlays = [
    (self: super: {
      go = super.go.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ (
          if lib.stdenv.isDarwin then [ ./fd_fsync_darwin.patch ]
          else [ ]
        );
      });
    })
  ];

  # services.lorri.enable = true;
  home.packages = with pkgs; [
    direnv
    niv

    git
    bat # cat alternative
    exa # ls alternative
    glances # top alternative
    hyperfine # benchmarking
    fd
    graphviz
    jq
    tokei
    hugo
    age
    silver-searcher
    zlib
    llvm_10
    lldb_10
    libwebp

    # pkgs.delve
    # pkgs.protobuf
    modd
    automake
    autoconf

    direnv

    # pkgs.coreutils-full

    python
    python3

    lua5_3

    # rust. eventually, see about using
    # https://github.com/mozilla/pkgs-mozilla
    # rustup manages rustc, cargo, etc. perhaps it
    # should also manage rust-analyzer?
    rustup
    rust-analyzer
    # pkgs.cargo
    # pkgs.rustfmt

    # nix language server
    # rnix-lsp

    # delve
    # protobuf
    golangci-lint # XXX fixme: maybe bring this guy back w/ lorri/direnv?

    # detect-secrets
    contrast-detect-secrets
    pre-commit
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
    package = pkgs.go;
    goPath = "${builtins.getEnv "HOME"}/gopath";
    goBin = "${builtins.getEnv "HOME"}/gobin";
  };
}
