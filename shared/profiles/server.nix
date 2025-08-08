# Server profile: headless system services
{ config, lib, pkgs, VARS, mylib, ... }:
{
  # Server-only tunables
  services = {
    # Headless; no desktop stack here.

    # ZFS housekeeping (if ZFS present)
    zfs = {
      autoScrub.enable = true;
      autoSnapshot = {
        enable = false;
        monthly = 4;
        weekly = 7;
        daily = 2;
        hourly = 24;
        frequent = 4;
        flags = "-u";
      };
      trim.enable = true;
    };
  };

  # Container runtime shared elsewhere
}
