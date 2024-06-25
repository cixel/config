# https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4
{ pkgs, ... }:
{
  imports = [ ];

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
  services.openssh.settings.PasswordAuthentication = false;
  programs.mosh.enable = true;
  services.tailscale.enable = true;

  networking = {
    hostName = "banjo";
  };
}
