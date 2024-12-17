{ config, lib, pkgs, ... }:

{
  services.sanoid = {
    enable = true;

    templates = {
      "production" = {
        autosnap = true;
        autoprune = true;
        yearly = 4;
        monthly = 4;
        weekly = 3;
        daily = 4;
        hourly = 0;
      };
    };

    datasets = {
      tank = {
        useTemplate = [ "production" ];
        recursive = true;
      };

      flash_temp = {
        useTemplate = [ "production" ];
        recursive = true;
      };
    };

    settings = { };
  };

  environment.systemPackages = with pkgs; [
    sanoid # ZFS snapshot management
  ];
}
