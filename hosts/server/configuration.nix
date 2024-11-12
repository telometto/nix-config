/*
 * Host-specific system configuration defaults
 * Edit this configuration file to define what should be installed on
 * your system.  Help is available in the configuration.nix(5) man page
 * and in the NixOS manual (accessible by running ‘nixos-help’).
*/

{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Import common configurations
    ../../common/imports.nix

    # Import modules configurations
    ../../modules/imports.nix

    # Server-specific settings
    ./boot/defaults.nix

    ./environment/defaults.nix

    ./networking/defaults.nix
    ./networking/systemd/systemd-networking.nix
    ./networking/tailscale/tailscale.nix
    ./networking/vlan/vlans.nix

    ./packages/defaults.nix

    ../../modules/services/backups/borg.nix
    ../../modules/services/documents/paperless.nix
    #../../modules/services/finance/firefly.nix
    ../../modules/services/internet/searx.nix
    #../../modules/services/media/immich.nix
    #../../modules/services/media/nixarr.nix
    ../../modules/services/media/plex.nix

    #./utilities/filesystem/filebrowser.nix
    ./utilities/filesystem/sanoid.nix
    ./utilities/filesystem/scrutiny.nix
    ./utilities/monitoring/cockpit.nix

    ./virtualization/orchestration/k3s.nix

    ../../common/users/server/server.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  /*
  * Some programs need SUID wrappers, can be configured further or are
  * started in user sessions.
  * programs.mtr.enable = true;
  *
  * Copy the NixOS configuration file and link it from the resulting system
  * (/run/current-system/configuration.nix). This is useful in case you
  * accidentally delete configuration.nix.
  * system.copySystemConfiguration = true;
  *
  * This option defines the first version of NixOS you have installed on this particular machine,
  * and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  *
  * Most users should NEVER change this value after the initial install, for any reason,
  * even if you've upgraded your system to a new NixOS release.
  *
  * This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  * so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  * to actually do that.
  *
  * This value being lower than the current NixOS release does NOT mean your system is
  * out of date, out of support, or vulnerable.
  *
  * Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  * and migrated your data accordingly.
  *
  * For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  */
  system.stateVersion = "24.05"; # Did you read the comment?

}
