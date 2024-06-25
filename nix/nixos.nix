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
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKROMn7wno7gHpTy2PcnVMh2s4/95Ft3h6Cem96VLIsC"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQ0joHvM6ItsXqrzcITjDw/5fGCcQ33/wDum3J7Q/am"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMUsyFLFFOgk67VeuJWQQQYaV6Rv6jcNqx6wub00U5F"
    ];
  };
}
