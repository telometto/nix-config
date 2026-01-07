{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.sys.services.nfs;
  inherit (lib) types;

  mkWhat = m: "${m.server}:${m.export}";
  mkMount = _: m: {
    type = "nfs";
    what = mkWhat m;
    where = m.target;
    # systemd [Mount] section uses Options= (capital O)
    mountConfig.Options = lib.concatStringsSep "," m.options;
  };
  mkAutomount = _: m: {
    where = m.target;
    inherit (m) wantedBy;
    automountConfig.TimeoutIdleSec = toString m.idleTimeout;
  };

  mountsList = lib.mapAttrsToList mkMount cfg.mounts;
  automountsList = lib.mapAttrsToList mkAutomount cfg.mounts;

  nfsPorts = [
    2049
    111
  ];

  serverPorts = [
    cfg.server.statdPort
    cfg.server.lockdPort
    cfg.server.mountdPort
  ];

in
{
  options.sys.services.nfs = {
    enable = lib.mkEnableOption "NFS client/server configuration";

    mounts = lib.mkOption {
      type = types.attrsOf (
        types.submodule (
          { lib, ... }:
          {
            options = {
              server = lib.mkOption {
                type = types.str;
                description = "NFS server hostname or IP";
              };

              export = lib.mkOption {
                type = types.str;
                description = "Remote export path (e.g. /pool/share)";
              };

              target = lib.mkOption {
                type = types.str;
                description = "Local mountpoint";
              };

              options = lib.mkOption {
                type = types.listOf types.str;
                default = [
                  "rw"
                  "noatime"
                  "nofail"
                ];
                description = "Mount options (comma-joined)";
              };

              idleTimeout = lib.mkOption {
                type = types.int;
                default = 600;
                description = "Idle timeout in seconds (systemd TimeoutIdleSec)";
              };

              wantedBy = lib.mkOption {
                type = types.listOf types.str;
                default = [ "multi-user.target" ];
                description = "Targets that want the automount unit";
              };
            };
          }
        )
      );
      default = { };
      description = "Declarative NFS mounts; automounts are generated automatically.";
    };

    server = {
      enable = lib.mkEnableOption "NFS server";

      lockdPort = lib.mkOption {
        type = types.port;
        default = 4001;
      };

      mountdPort = lib.mkOption {
        type = types.port;
        default = 4002;
      };

      statdPort = lib.mkOption {
        type = types.port;
        default = 4000;
      };

      exports = lib.mkOption {
        type = types.lines;
        default = "";
        description = "/etc/exports entries (NFSv4)";
      };

      openFirewall = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for NFSv4 and helpers";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot = {
          supportedFilesystems = lib.mkDefault [ "nfs" ];
          initrd.supportedFilesystems.nfs = lib.mkDefault true;
        };
        environment.systemPackages = with pkgs; [
          libnfs
          nfs-utils
        ];
        systemd.mounts = mountsList;
        systemd.automounts = automountsList;
      }

      (lib.mkIf cfg.server.enable {
        services.rpcbind.enable = lib.mkDefault true;
        services.nfs.server = {
          enable = true;
          inherit (cfg.server)
            lockdPort
            mountdPort
            statdPort
            exports
            ;
        };

        networking.firewall = lib.mkIf cfg.server.openFirewall {
          allowedTCPPorts = nfsPorts ++ serverPorts;
          allowedUDPPorts = nfsPorts ++ serverPorts;
        };
      })
    ]
  );
}
