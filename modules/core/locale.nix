# Automatically imported
{ lib, pkgs, ... }:
let LANGUAGE = "nb_NO.UTF-8";
in {
  time.timeZone = lib.mkDefault "Europe/Oslo";

  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    glibcLocales = pkgs.glibcLocales.override { allLocales = true; };
    extraLocaleSettings = lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: LANGUAGE);
  };

  services.xserver.xkb.layout = lib.mkDefault "no";
  console.useXkbConfig = lib.mkDefault true;
}
