{ system, user, ... }: { ... }: {
  imports = [
    (import ../work.nix { inherit system user; })
  ];
}
