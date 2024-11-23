/**
 * This Nix module configures hardware settings for the GPU, specifically
 * for OpenGL and general graphics support. It allows toggling between
 * stable and unstable releases by setting the `stableRelease` variable.
 *
 * Variables:
 * - stableRelease: A boolean flag to switch between stable and unstable
 *   releases. When set to true, it enables stable OpenGL settings. When
 *   set to false, it enables unstable graphics settings.
 *
 * Configuration:
 * - hardware.opengl: Configures OpenGL settings if `stableRelease` is true.
 *   - enable: Enables OpenGL support.
 *   - driSupport: Enables Direct Rendering Infrastructure (DRI) support.
 *   - driSupport32Bit: Enables 32-bit DRI support.
 * - hardware.graphics: Configures general graphics settings if `stableRelease`
 *   is false.
 *   - enable: Enables general graphics support.
 *   - enable32Bit: Enables 32-bit graphics support.
 */

{ config, lib, pkgs, myVars, ... }:

let
  stableRelease = false; # Set this to true to enable the stable release
in
{
  hardware = {
    opengl =
      if stableRelease then {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      } else { };

    graphics =
      if !stableRelease then {
        enable = true;
        enable32Bit = true;
      } else { };
  };
}
