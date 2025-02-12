{ config, lib, pkgs, ... }:

{
  system = {
    autoUpgrade = {
      enable = true;

      flake = "github:telometto/nix-config";
      operation = "boot";
      flags = [ ];
      dates = "weekly";

      rebootWindow = {
        lower = "04:00";
        upper = "05:30";
      };

      persistent = true;
      allowReboot = true;
      fixedRandomDelay = true;
      randomizedDelaySec = "20min";
    };
  };

  services.cron = {
    enable = true;

    systemCronJobs = [
      "15 * * * * zeno cd /home/zeno/.versioncontrol/github/nix-config && git fetch && git pull"
    ];
  };
}
