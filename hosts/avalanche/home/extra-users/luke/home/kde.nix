{ config, lib, pkgs, VARS, ... }:

{
  home.packages = with pkgs; [
    # Your KDE packages here
    kdePackages.kate
    kdePackages.kdeconnect-kde
    kdePackages.kcalc
  ];

  #qt = {
  #  enable = true;
  #  platformTheme.name = "adwaita"; # "qtct";
  #  style.name = "adwaita"; # "kvantum";
  #};

  #xdg.configFile = {
  #  "Kvantum/ArcDark".source = "${pkgs.arc-kde-theme}/share/Kvantum/ArcDark";
  #  "Kvantum/kvantum.kvconfig".text = "[General]\ntheme=ArcDark";
  #};

  #programs = {
  #  light.brightnessKeys.enable = true;
  #};
}
