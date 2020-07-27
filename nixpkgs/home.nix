{ config, pkgs, ... }:

let
  # set channel channel to nixpkgs-unstable
  nixpkgs = import <nixpkgs> {};

  # https://discourse.nixos.org/t/is-it-possible-to-override-cargosha256-in-buildrustpackage/4393/2
  starship = nixpkgs.starship.overrideAttrs (
    drv: rec {
      src = nixpkgs.fetchFromGitHub {
        owner = "starship";
        repo = "starship";
        rev = "a89f41f8e8e3691d6499357509ff5f293dcf8007";
        sha256 = "0fqbbax783bp066wqhb3qmiw262da25kjb2ypsfcq3k8bxxw8qlr";
      };
      cargoDeps = drv.cargoDeps.overrideAttrs (
        nixpkgs.lib.const {
          inherit src;
          outputHash = "0j0l5gngkdyns83r5aplr9psvhd9mff7s9r4h2dfial07jm5rwds";
        }
      );
    }
  );

  # starship_src = import ./starship.nix;
  # starship = nixpkgs.callPackage starship_src { Security= nixpkgs.darwin.apple_sdk.frameworks.Security; };
  # mozilla-overlays = fetchTarball {
  #     url = https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz;
  # };
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
    starship
    # nixpkgs.starship
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

    # I can add the tmux.conf here as well
    nixpkgs.tmux
  ];

  programs.zsh = import ./zsh-conf.nix { pkgs = nixpkgs; };
  programs.tmux = import ./tmux-conf.nix { pkgs = nixpkgs; };

  programs.neovim = {
    enable = true;

    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;

    extraConfig = builtins.readFile "${builtins.getEnv "HOME"}/.config/nvim/init.vim";
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

