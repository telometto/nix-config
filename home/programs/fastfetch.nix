{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.fastfetch;
in
{
  options.hm.programs.fastfetch = {
    enable = lib.mkEnableOption "Fastfetch system information utility";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fastfetch;
      description = "Fastfetch package to use.";
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
      default = [ ];
      description = "Modules appended to the shared Fastfetch list for specific hosts.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Fastfetch settings merged with the shared defaults.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fastfetch = {
      enable = lib.mkDefault true;

      inherit (cfg) package;

      settings = lib.mkMerge [
        {
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
            "de"
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
            {
              "type" = "disk";
              "hideFS" = "zfs";
            }
          ]
          ++ cfg.extraModules
          ++ [
            # To be added/overridden on laptop only
            # {
            #   "type" = "battery";
            #   "temp" = true;
            # }
            { "type" = "localip"; }
            {
              "type" = "weather";
              "timeout" = 1000;
            }
            "break"
          ];
        }
        cfg.extraSettings
      ];
    };
  };
}
