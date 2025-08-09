# Module to declaratively manage NFS exports using a simple list.
{ lib, config, ... }:
let
  inherit (lib) mkOption types mkIf concatStringsSep mapAttrsToList;
  cfg = config.my.nfs;
  exportsText = concatStringsSep "\n" (map
    (e:
      let
        opts = e.options or "rw,sync,nohide,no_subtree_check";
        networks = e.networks or [ "127.0.0.1/32" ];
        nets = concatStringsSep " " (map (n: "${n}(${opts})") networks);
      in
      "${e.path} ${nets}"
    )
    cfg.exports);
  hasExports = cfg.exports != [ ];
in
{
  options.my.nfs = {
    exports = mkOption {
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          path = mkOption { type = types.str; description = "Absolute path to export"; };
          networks = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of CIDRs / hosts allowed";
          };
          options = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Export options string";
          };
        };
      }));
      default = [ ];
      description = "List of NFS exports";
    };
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Master toggle for NFS server if exports present";
    };
    ports = {
      lockd = mkOption { type = types.int; default = 4001; };
      mountd = mkOption { type = types.int; default = 4002; };
      statd = mkOption { type = types.int; default = 4000; };
    };
  };

  config = mkIf (cfg.enable && hasExports) {
    services.nfs.server = {
      enable = true;
      lockdPort = cfg.ports.lockd;
      mountdPort = cfg.ports.mountd;
      statdPort = cfg.ports.statd;
      exports = exportsText + "\n";
    };
  };
}
