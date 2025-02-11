{ config, lib, pkgs, ... }:

{
  services.actual = {
    enable = true;

    openFirewall = true;

    settings = {
      # hostname = "";
      port = 3838;
    };
  };
}