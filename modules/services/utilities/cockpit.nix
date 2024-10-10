{ config, lib, pkgs, ... }:

{
  services = {
    cockpit = {
      enable = true;
      port = 9090;
      openFirewall = true;

      settings = {
        WebService = {
          AllowUnencrypted = true;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [ cockpit ];
}
