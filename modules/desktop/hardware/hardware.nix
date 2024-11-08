{ config, lib, pkgs, myVars, ... }:

{
  hardware = {
#    # For stable release
#    opengl = {
#      enable = true;
#
#      driSupport = true;
#      driSupport32Bit = true;
#    };

    # For unstable release
    graphics = {
      enable = true;

      enable32Bit = true;
    };

    openrazer = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [ openrazer-daemon ];
}
