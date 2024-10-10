# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;

    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };

    openFirewall = true;
  };
}
