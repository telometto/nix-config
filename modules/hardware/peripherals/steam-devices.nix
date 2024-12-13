/**
 * This NixOS module enables support for Steam hardware devices.
 * It sets the `hardware.steam-hardware.enable` option to `true`,
 * which ensures that the necessary drivers and configurations
 * for Steam devices are loaded and available on the system.
 */

{ config, lib, pkgs, VARS, ... }:

{
  hardware.steam-hardware.enable = true;
}
