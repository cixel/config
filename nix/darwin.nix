{ user }: { pkgs, ... }: {
  # Auto upgrade nix package and the daemon service.
  # TODO: is it wrong/incorrect to let nix-darwin manage this given that it was
  # installed by the detsys nix installer?
  services.nix-daemon.enable = false;

  nix = {
    # We install Nix using a separate installer so we don't want nix-darwin
    # to manage it for us. This tells nix-darwin to just use whatever is running.
    useDaemon = true;
  };

  # settings required for local builder
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 8 * 1024;
          memorySize = 40 * 1024;
        };
        cores = 4;
      };
    };
  };
  nix.settings.trusted-users = [ "@admin" ];

  programs.zsh = {
    enable = true;
    shellInit = ''
      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
      # End Nix
    '';
  };

  users.users."${user}" = {
    home = "/Users/${user}";
    createHome = false;
    shell = pkgs.zsh;
  };
}
