{ user, ... }: { ... }: {
  imports = [
    (import ../work.nix { inherit user; })
  ];
}
