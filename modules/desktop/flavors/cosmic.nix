{
  lib,
  config,
  # pkgs,
  ...
}:
let
  flavor = config.telometto.desktop.flavor or "none";
  is = v: flavor == v;
in
{
  config = lib.mkIf (is "cosmic") {
    services = {
      xserver.enable = lib.mkDefault false;
      desktopManager.cosmic.enable = true;

      displayManager.cosmic-greeter = {
        enable = true;
      };
    };

    environment = {
      sessionVariables = {
        COSMIC_DATA_CONTROL_ENABLED = 1;
      };

      systemPackages = [ ];
    };
  };
}
