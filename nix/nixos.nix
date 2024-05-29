{ user }: { pkgs, ... }: {
  system.stateVersion = "24.05";

  programs.zsh = {
    enable = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    createHome = true;
    shell = pkgs.zsh;
  };
}
