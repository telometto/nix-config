/**
 * This NixOS configuration file sets up default programs and system packages.
 * It enables and configures specific programs and their features.
 * 
 * - `programs`: Contains configurations for various programs.
 *   - `gnupg`: Configures GnuPG (GNU Privacy Guard) settings.
 *     - `agent`: Enables the GnuPG agent and SSH support.
 * 
 * - `environment.systemPackages`: Specifies system-wide packages to be installed.
 *   - Includes `gnupg` as a system package.
 */

{ config, lib, pkgs, ... }:

{
  programs = {
    #mtr = { enable = true; }; # traceroute and ping in a single tool

    gnupg = {
      agent = {
        enable = true;

        enableSSHSupport = false;

        settings = {
          default-cache-ttl = 34560000; # 400 days
          max-cache-ttl = 34560000; # 400 days
        };
      };
    };

    ssh = {
      startAgent = true;
      enableAskPassword = true;
      askPassword = pkgs.lib.mkForce "${pkgs.ksshaskpass.out}/bin/ksshaskpass";
    };

    zsh = { enable = true; };
  };

  environment.systemPackages = with pkgs; [
    gnupg
    zsh
  ];
}
