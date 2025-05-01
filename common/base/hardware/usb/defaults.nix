/**
 * This NixOS configuration module enables USB support and sets up related services and packages.
 * It enables the `gvfs` and `udisks2` services for managing USB devices and removable disks.
 * Additionally, it installs `usbutils`, `udiskie`, and `udisks` packages for USB device utilities,
 * removable disk automounting, and disk management services respectively.
 */

{ config, lib, pkgs, ... }:

{
  # Enable USB support.
  services = {
    devmon = {
      enable = true;
    };

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
