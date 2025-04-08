# https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4
{ ... }: { pkgs, ... }:
{
  imports = [ ];

  overlays = [
    (self: super: {
      # https://github.com/NixOS/nixpkgs/issues/154163#issuecomment-1350599022
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
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
  services.openssh.settings.PasswordAuthentication = false;
  programs.mosh.enable = true;
  services.tailscale.enable = true;
  networking.hostName = "banjo";

  # https://nix.dev/tutorials/nixos/installing-nixos-on-a-raspberry-pi.html
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };
}
