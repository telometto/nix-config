# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.atuin = {
    enable = true;
  };

  # Uncomment the line below to install system-wide
  # environment.systemPackages = with pkgs; [ atuin ];
}
