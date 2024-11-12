{ config, lib, pkgs, myVars, ... }:

{
  home.packages = with pkgs; [
    # Your KDE packages here
  ];

  qt = {
    enable = true;
    platformTheme.name = "gnome"; # "qtct";
    style.name = "adwaita"; # "kvantum";
  };

  #xdg.configFile = {
  #  "Kvantum/ArcDark".source = "${pkgs.arc-kde-theme}/share/Kvantum/ArcDark";
  #  "Kvantum/kvantum.kvconfig".text = "[General]\ntheme=ArcDark";
  #};

  #programs = {
  #  light.brightnessKeys.enable = true;
  #};
}