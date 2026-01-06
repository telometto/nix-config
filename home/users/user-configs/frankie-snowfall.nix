# User-specific configuration for frankie user on snowfall host
# This file is automatically imported only for the frankie user on snowfall
{
  lib,
  pkgs,
  ...
}:
let
  LANGUAGE = "it_IT.UTF-8";
in
{
  # User-specific packages for frankie on snowfall
  home.packages = [
    pkgs.variety # Wallpaper changer
    pkgs.polychromatic # Razer configuration tool
  ];

  home = {
    language = {
      address = lib.mkForce LANGUAGE;
      base = lib.mkForce LANGUAGE;
      collate = lib.mkForce LANGUAGE;
      ctype = lib.mkForce LANGUAGE;
      measurement = lib.mkForce LANGUAGE;
      messages = lib.mkForce LANGUAGE;
      monetary = lib.mkForce LANGUAGE;
      name = lib.mkForce LANGUAGE;
      numeric = lib.mkForce LANGUAGE;
      paper = lib.mkForce LANGUAGE;
      telephone = lib.mkForce LANGUAGE;
      time = lib.mkForce LANGUAGE;
    };
  };

  hm = {
    programs = {
      media.jf-mpv.enable = false;
    };
  };
}
