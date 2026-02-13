{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.sabnzbd;
  inherit (cfg) configFile;
  port = toString cfg.port;
  execStart = "${pkgs.sabnzbd}/bin/sabnzbd -f ${configFile} -s 0.0.0.0:${port}";
in
{
  options.sys.services.sabnzbd = {
    enable = lib.mkEnableOption "SABnzbd";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Web UI port for SABnzbd.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sabnzbd";
      description = "State/config directory for SABnzbd.";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sabnzbd/sabnzbd.ini";
      description = "Path to SABnzbd config file.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.sabnzbd = {
      description = "SABnzbd";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = [ "users" ];
        ExecStart = execStart;
        Restart = "on-failure";
        UMask = "002";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
