# Laptop-specific program configurations
{ config, lib, pkgs, VARS, ... }:

let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
  browserPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableFirefoxAccounts = false;
    DontCheckDefaultBrowser = true;
    DisplayBookmarksToolbar = "always";
    DisplayMenuBar = "default-off";
    SearchBar = "unified";
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Cryptomining = true;
      Fingerprinting = true;
    };
  };
  fastfetchModulesCommon = [
    "title"
    "separator"
    "os"
    "kernel"
    "initsystem"
    "uptime"
    "loadavg"
    "processes"
    "packages"
    "shell"
    "editor"
    "display"
    "de"
    "terminal"
    {
      "type" = "cpu";
      "showPeCoreCount" = true;
      "temp" = true;
    }
    "cpuusage"
    {
      "type" = "gpu";
      "driverSpecific" = true;
      "temp" = true;
    }
    "memory"
    "swap"
    "disk"
    { "type" = "localip"; }
    {
      "type" = "weather";
      "timeout" = 1000;
    }
    "break"
  ];
in
{
  programs = {
    fastfetch.settings.modules = fastfetchModulesCommon;

    firefox = {
      enable = false;
      languagePacks = LANGUAGES;
      policies = browserPolicies // {
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
      };
    };

    floorp = {
      enable = true;
      policies = browserPolicies;
    };
    mangohud.enable = true;
    mpv.enable = true;
    vesktop.enable = true; # minimal configuration relies on defaults
    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
