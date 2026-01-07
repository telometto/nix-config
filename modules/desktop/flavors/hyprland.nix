{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  flavor = config.sys.desktop.flavor or "none";
  is = v: flavor == v;
  haveHypr = inputs ? hyprland;
in
{
  config = lib.mkIf (is "hyprland") (
    lib.mkMerge [
      {
        programs.hyprland.enable = true;

        xdg.portal = {
          enable = lib.mkDefault true;
          xdgOpenUsePortal = lib.mkDefault true;
          config.common.default = lib.mkDefault "*";
        };

        environment.systemPackages = with pkgs; [
          waybar
          hyprpaper
          hypridle
          hyprlock
          foot
          wofi
        ];

        services.greetd.enable = lib.mkDefault true;
      }

      (lib.mkIf haveHypr {
        programs.hyprland.package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        programs.hyprland.portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        xdg.portal.extraPortals = lib.mkForce [
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
        ];
      })
    ]
  );
}
