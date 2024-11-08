# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  time.timeZone = "Europe/Oslo";

  i18n = {
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [ "all" ];

    extraLocaleSettings = {
      LC_ADDRESS = "nb_NO.UTF-8";
      LC_IDENTIFICATION = "nb_NO.UTF-8";
      LC_MEASUREMENT = "nb_NO.UTF-8";
      LC_MONETARY = "nb_NO.UTF-8";
      LC_NAME = "nb_NO.UTF-8";
      LC_NUMERIC = "nb_NO.UTF-8";
      LC_PAPER = "nb_NO.UTF-8";
      LC_TELEPHONE = "nb_NO.UTF-8";
      LC_TIME = "nb_NO.UTF-8";
    };
  };

  console = {
    #keyMap = "no";
    useXkbConfig = true; # use xkb.options in tty
    # font = "";
  };

  services = {
    xserver = {
      xkb = {
        layout = "no";
        variant = "";
        # options = "eurosign:e,caps:escape";
      };
    };
  };
}
