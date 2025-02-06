{ pkgs, ... }: { ... }: {
  imports = [ ];

  nix.linux-builder.enable = pkgs.lib.mkForce false;
}
