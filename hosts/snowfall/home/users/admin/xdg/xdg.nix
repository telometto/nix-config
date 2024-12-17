{ config, lib, pkgs, VARS, ... }:
{
  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
      };
    };
  };
}
