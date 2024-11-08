{ config, lib, pkgs, myVars, ... }:

{
  # Enable USB support.
  services = {
    gvfs = {
      enable = true;
    };

    udisks2 = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    usbutils # USB device related utilities
    udiskie # Removable disk automounter
    udisks # Disk management service
  ];
}
