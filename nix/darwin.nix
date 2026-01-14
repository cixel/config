{ user, pkgs, ... }:
{
  nix = {
    # We install Nix using a separate installer so we don't want nix-darwin
    # to manage it for us. This tells nix-darwin to just use whatever is running.
    enable = true;
  };
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Re-add darwin to podman's meta.platforms. Upstream nixpkgs commit
  # ebd782baf852 (2026-06-28) restricted podman to lib.platforms.linux,
  # which was reverted the next day in e288608304d1 ("podman: enable on
  # all Unix platforms"). The fix is in nixpkgs master but the
  # nixpkgs-unstable channel we track has not advanced past it yet. This
  # overlay cherry-picks the revert and can be dropped once we update
  # nixpkgs past e288608304d1.
  nixpkgs.overlays = [
    (final: prev: {
      # podman = prev.podman.overrideAttrs (old: {
      #   meta = old.meta // {
      #     platforms = old.meta.platforms ++ [
      #       "aarch64-darwin"
      #       "x86_64-darwin"
      #     ];
      #   };
      # });
    })
  ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # settings required for local builder
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 6;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 32 * 1024;
          memorySize = 8 * 1024;
        };
        cores = 6;
      };
    };
  };
  nix.settings.trusted-users = [ "@admin" ];

  programs.zsh = {
    enable = true;
    shellInit = '''';
  };
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    # FIXME: https://github.com/LnL7/nix-darwin/issues/139
    rectangle
  ];

  users.users.${user} = {
    home = "/Users/${user}";
    createHome = false;
    shell = pkgs.fish;
    # packages = with pkgs; [ ];
  };
}
