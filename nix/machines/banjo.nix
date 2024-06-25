# https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4
{ self, config, pkgs, lib, ... }:
{
  imports =
    [
      self.inputs.hardware.nixosModules.raspberry-pi-4
      # <nixos-hardware/raspberry-pi/4>
      # ./hardware-configuration.nix
    ];

  time.timeZone = "America/New_York";


  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };
  console.enable = false;
  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];

  services.openssh.enable = true;
  programs.mosh.enable = true;
  services.tailscale.enable = true;
  services.resolved.enable = true;

  networking = {
    hostname = "banjo";
    resolvconf.enable = true;
  };
}
