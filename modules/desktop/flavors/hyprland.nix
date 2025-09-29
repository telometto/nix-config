{ lib, config, pkgs, inputs, ... }:
# Single-owner Hyprland flavor under rewrite/, gated by telometto.desktop.flavor
let flavor = config.telometto.desktop.flavor or "none";
    is = v: flavor == v;
    haveHypr = inputs ? hyprland;
in {
  config = lib.mkIf (is "hyprland") (lib.mkMerge [
    {
      # Enable Hyprland and align portal package with the input if present
      programs.hyprland.enable = true;

      # Wayland-friendly defaults
      xdg.portal = {
        enable = lib.mkDefault true;
        xdgOpenUsePortal = lib.mkDefault true;
        config.common.default = lib.mkDefault "*";
      };

      # Common tooling for Hyprland workflows
      environment.systemPackages = with pkgs; [
        waybar hyprpaper hypridle hyprlock
        foot wofi
      ];

      # Pick a display manager if you need one; otherwise use greetd or none.
      # Keep this minimal; user can add their preferred greeter.
      services.greetd.enable = lib.mkDefault true;
    }

    # Only set Hyprland packages and portals when the hyprland input is present
    (lib.mkIf haveHypr {
      programs.hyprland.package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      programs.hyprland.portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      xdg.portal.extraPortals = lib.mkForce [ inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland ];
    })
  ]);
}
