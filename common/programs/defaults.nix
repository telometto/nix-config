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

    zsh = { enable = true; };

    #mtr = { enable = true; }; # traceroute and ping in a single tool
  };

  environment.systemPackages = with pkgs; [
    gnupg
    zsh
  ];
}
