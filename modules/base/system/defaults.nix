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

  systemd.services."nix-config-update" = {
    description = "Update nix-config repository periodically";
    serviceConfig = {
      Type = "oneshot";
      User = "zeno";
      WorkingDirectory = "/home/zeno/.versioncontrol/github/projects/personal/nix-config";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.git}/bin/git fetch && ${pkgs.git}/bin/git pull'";
    };
  };

  systemd.timers."nix-config-timer" = {
    description = "Timer for updating the nix-config repository";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:15:00";
      Persistent = true;
    };
    service = "nix-config-update.service";
  };
}
