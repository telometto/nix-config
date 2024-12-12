/**
 * This NixOS configuration file sets up internationalization (i18n) and localization settings.
 * It configures the system's time zone, default locale, supported locales, and various locale-specific settings.
 * Additionally, it configures console and X server settings for keyboard layout and options.
 * The configuration also ensures that the necessary system packages for locale support are installed.
 *
 * - `time.timeZone`: Sets the system time zone to "Europe/Oslo".
 * - `i18n.defaultLocale`: Sets the default locale to "en_US.UTF-8".
 * - `i18n.supportedLocales`: Specifies the supported locales, in this case, all locales.
 * - `i18n.extraLocaleSettings`: Defines additional locale settings for various categories using the Norwegian Bokmål locale.
 * - `console.useXkbConfig`: Enables the use of XKB configuration in the console.
 * - `services.xserver.xkb.layout`: Sets the X server keyboard layout to Norwegian.
 * - `environment.systemPackages`: Ensures that the `glibcLocales` package is installed for locale support.
 */

{ config, lib, pkgs, ... }:
let
  LANGUAGE = "nb_NO.UTF-8"; # Norwegian Bokmål locale
in
{
  time.timeZone = "Europe/Oslo";

  i18n = {
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [ "all" ]; # Support all locales

    extraLocaleSettings = {
      LC_ADDRESS = LANGUAGE;
      LC_IDENTIFICATION = LANGUAGE;
      LC_MEASUREMENT = LANGUAGE;
      LC_MONETARY = LANGUAGE;
      LC_NAME = LANGUAGE;
      LC_NUMERIC = LANGUAGE;
      LC_PAPER = LANGUAGE;
      LC_TELEPHONE = LANGUAGE;
      LC_TIME = LANGUAGE;
    };
  };

  console = {
    useXkbConfig = true; # use xkb.options in tty
    # font = "FiraCode";
  };

  services = {
    xserver = {
      xkb = {
        layout = "no";
        variant = ""; # Example: "variant = dvorak";
        # options = "eurosign:e,caps:escape";
      };
    };
  };

  environment.systemPackages = with pkgs; [ glibcLocales ];
}
