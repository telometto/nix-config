{ config, lib, pkgs, ... }:
{
  programs = {
    xwayland = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    kdePackages.qtwayland
    xwayland
    kdePackages.xwaylandvideobridge
  ];
}
