# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ user }: { pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = user;
  # don't want this stepping on tailscale's toes
  wsl.wslConf.network.generateResolvConf = false;
  wsl.useWindowsDriver = true;

  services.tailscale.enable = true;
  services.resolved.enable = true;
  networking.resolvconf.enable = false;

  imports = [
    # "${modulesPath}/profiles/minimal.nix"
    {
      # services.udisks2.enable = false;
      # xdg.autostart.enable = false;
      # xdg.icons.enable = false;
      # xdg.mime.enable = false;
      # xdg.sounds.enable = false;
    }
  ];

  security.sudo.wheelNeedsPassword = false;

  networking.hostName = "alnitak-wsl";
  time.timeZone = "America/New_York";

  nix = {
    settings = {
      accept-flake-config = true;
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };

  services.openssh.enable = true;
  programs.mosh.enable = true;
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    tmux
    git
  ];
}
