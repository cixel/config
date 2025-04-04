{ user }: { pkgs, ... }: {
  nix = {
    # We install Nix using a separate installer so we don't want nix-darwin
    # to manage it for us. This tells nix-darwin to just use whatever is running.
    enable = true;
  };
  nixpkgs.config = {
    allowUnfree = true;
  };

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
    shellInit = ''
    '';
  };

  environment.systemPackages = with pkgs; [
    # FIXME: https://github.com/LnL7/nix-darwin/issues/139
    rectangle
  ];

  users.users.${user} = {
    home = "/Users/${user}";
    createHome = false;
    shell = pkgs.zsh;
    # packages = with pkgs; [ ];
  };
}
