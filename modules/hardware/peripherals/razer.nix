/**
 * This NixOS module configuration enables support for Razer peripherals
 * using the OpenRazer driver. It sets up the necessary hardware configuration
 * and installs the OpenRazer daemon as a system package.
 *
 * - `hardware.openrazer.enable = true;` enables the OpenRazer driver.
 * - `environment.systemPackages = with pkgs; [ openrazer-daemon ];` adds the OpenRazer daemon to the system packages.
 */

{ config, lib, pkgs, myVars, ... }:

lib.mkIf (config.networking.hostName == myVars.desktop.hostname)
{
  hardware = {
    openrazer = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [ openrazer-daemon ];
}
