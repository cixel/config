{ ... }: {
  imports = [
    ../work.nix
  ];

  environment.variables = {
    "TERM=screen",
  };
}
