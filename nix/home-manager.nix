{ self, system, user, ... }:
let
  darwin = builtins.match ".*darwin" system != null;
  hm = self.inputs.home-manager;
in
{
  imports = [
    (if darwin
     then hm.darwinModules.home-manager
     else hm.nixosModules.home-manager)
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.verbose = true;
  home-manager.backupFileExtension = "bak";
  home-manager.users.${user} = import ./home-manager/home.nix {
    inherit darwin;
  };
}
