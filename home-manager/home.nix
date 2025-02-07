{ darwin, wsl }:
{ pkgs, lib, ... }:

let
  contrast-detect-secrets = pkgs.python3Packages.callPackage ./detect-secrets.nix { };
in
{
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  home.packages = with pkgs; [
    git
    curl
    ripgrep
    bat
    eza
    # glances # top alternative
    hyperfine # benchmarking
    fd
    graphviz
    jq
    tokei
    age
    silver-searcher
    python3
    luajit
    rustup
    zig

    # this won't be useable as a server because it's only available to a single
    # user.
    mosh
    openssh

    # i use these for work and prefer having them already loaded to avoid
    # needing to enter a nix shell for random build dependencies
    contrast-detect-secrets
    golangci-lint
    xz
    gnumake

    podman
    podman-compose

    jujutsu
  ];

  home.shellAliases = {
    hms =
      if darwin then
        "nix run nix-darwin -- -v -L switch --flake path:$HOME/.config"
      else
        "sudo nixos-rebuild switch -v --flake path:$HOME/.config";

    v = "nvim";
    sudov = "sudo -E -s nvim";

    l = "eza --long --all";
    lt = "eza --long --all --sort newest";
    ls = "eza";
    tree = "eza --tree --long";

    gd = "go doc";
    gdu = "go doc -u";
  };

  programs.neovim = import ./nvim { inherit pkgs; };
  programs.starship = import ./starship.nix { inherit pkgs lib; };
  programs.tmux = import ./tmux.nix { inherit pkgs; };
  programs.zsh = import ./zsh.nix { inherit pkgs; };
  programs.alacritty = import ./alacritty.nix {
    inherit pkgs wsl;
    shell = "${pkgs.zsh}/bin/zsh";
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    flags = [ "--disable-up-arrow" ];
    settings = {
      update_check = false;
      auto_sync = false;
      style = "compact";
      inline_height = 20;
      filter_mode_shell_up_key_binding = "session";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    enableFishIntegration = false;

    defaultCommand = "fd";
    fileWidgetCommand = "fd --hidden --exclude '.git'";
    changeDirWidgetCommand = "fd --type d --hidden --exclude '.git' --follow";
  };

  programs.go = {
    enable = true;
    package = pkgs.go;
    # these are interpreted relative to $HOME
    goPath = "gopath";
    goBin = "gobin";
    # TODO: it'd be nice if this is only set on work machines but that'd take a
    # refactor
    goPrivate = [
      "github.com/Contrast-Security-Inc/*"
    ];
  };
}
