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

  # The concrete GNOME/KDE/Hyprland settings live under modules/desktop/flavors/*.nix
  # Each flavor module wraps config in lib.mkIf (flavor == "...") to keep things
  # exclusive and avoid bloat.

  config = lib.mkMerge [ (lib.mkIf (is "none") mkNone) ];
}
