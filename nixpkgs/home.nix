{ config, pkgs, ... }:

let
  # set channel channel to pkgs-unstable
  pkgs = import <nixpkgs> {};
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
  # pkgs.config.allowUnfree = true;
  # pkgs.overlays = [ (import "${mozilla-overlays}") ];

  home.packages = with pkgs; [
    git
    bat
    exa
    fd
    graphviz
    jq
    starship
    tokei
    hugo
    ffmpeg-full
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
    rnix-lsp

    golangci-lint
  ];

  programs.zsh = import ./zsh-conf.nix { pkgs = pkgs; };
  programs.tmux = import ./tmux-conf.nix { pkgs = pkgs; };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;

    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;

    # plugins = with pkgs; [
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
