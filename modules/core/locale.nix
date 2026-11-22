{ lib, pkgs, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Oslo";

  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    glibcLocales = pkgs.glibcLocales.override { allLocales = true; };
  };

  services.xserver.xkb.layout = lib.mkDefault "no";
  console.useXkbConfig = lib.mkDefault true;
}
