{ config, lib, pkgs, VARS, ... }:

{
  programs = {
    fastfetch = {
      enable = true;

      settings = {
        # logo.source = "nixos_small";

        modules = [
          "title"
          "separator"
          "os"
          "kernel"
          "initsystem"
          "uptime"
          "loadavg"
          "processes"
          "packages"
          "shell"
          "editor"
          "display"
          "terminal"
          {
            "type" = "cpu";
            "showPeCoreCount" = true;
            "temp" = true;
          }
          "cpuusage"
          {
            "type" = "gpu";
            "driverSpecific" = true;
            "temp" = true;
          }
          "memory"
          "swap"
          "disk"
          "zpool"
          { "type" = "localip"; }
          {
            "type" = "weather";
            "timeout" = 1000;
          }
          "break"
        ];
      };
    };

    keychain = {
      keys = [ "borg-blizzard" "sops-hm-blizzard" "zeno-blizzard" ];
    };

    zsh = {
      shellAliases = {
        # Kubernetes
        k = "kubectl";
        kap = "kubectl apply -f";
        kdl = "kubectl delete";
        kgt = "kubectl get";
        kex = "kubectl exec -it";
        klo = "kubectl logs";
        kev = "kubectl events";
        kds = "kubectl describe";
      };
    };
  };
}
