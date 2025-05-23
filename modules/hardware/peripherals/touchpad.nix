/**
 * This Nix module is used to configure touchpad settings for a NixOS system.
 * It specifically disables the libinput service for touchpad support.
 */

{ config, lib, pkgs, ... }:

{
  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = false;
}
