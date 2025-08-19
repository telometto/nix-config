{ config, lib, pkgs, ... }:

{
  services.sanoid = {
    enable = true;

    templates = {
      "production" = {
        autosnap = true;
        autoprune = false;
        yearly = 2;
        monthly = 6;
        weekly = 4;
        daily = 7;
        hourly = 24;
        frequently = 0;
      };
    };

    datasets = {
      flash = {
        useTemplate = [ "production" ];
        recursive = "zfs";
      };

      rpool = {
        useTemplate = [ "production" ];
        recursive = "zfs";
      };
    };

    # settings = { };
  };
}
