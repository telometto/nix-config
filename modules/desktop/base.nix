{ lib, config, ... }:
let
  cfg = config.telometto.desktop;
  flavor = cfg.flavor or "none";
  is = v: flavor == v;
  mkNone = {
    services = {
      xserver.enable = lib.mkForce false;
      displayManager = {
        gdm.enable = lib.mkForce false;
        sddm.enable = lib.mkForce false;
      };
    };
  };
in
{
  options.telometto.desktop.flavor = lib.mkOption {
    type = lib.types.enum [
      "none"
      "gnome"
      "kde"
      "hyprland"
      "cosmic"
    ];
    default = "none";
    description = "Select Desktop Environment: none (headless), gnome, kde (Plasma), hyprland, or cosmic.";
  };

  config = lib.mkIf (is "none") mkNone;
}
