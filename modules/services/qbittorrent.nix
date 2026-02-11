{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.qbittorrent;
  torrentPort = cfg.torrentPort or null;
  tcpPorts = [ cfg.webPort ] ++ lib.optional (torrentPort != null) torrentPort;
  udpPorts = lib.optional (torrentPort != null) torrentPort;
  profileDir = cfg.dataDir;
  webPort = toString cfg.webPort;
  execStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=${webPort} --profile=${profileDir}";
in
{
  options.sys.services.qbittorrent = {
    enable = lib.mkEnableOption "qBittorrent (nox)";

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Web UI port for qBittorrent.";
    };

    torrentPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = 50820;
      description = "Incoming torrent port (TCP/UDP).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/qbittorrent";
      description = "State/config directory for qBittorrent.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "qbittorrent";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "qbittorrent";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    alternativeWebUI = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable alternative web UI (VueTorrent).";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.vuetorrent;
        description = "Alternative web UI package to use.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ]
    ++ lib.optionals cfg.alternativeWebUI.enable [
      "d ${cfg.dataDir}/qBt_webui 0750 ${cfg.user} ${cfg.group} -"
      "L+ ${cfg.dataDir}/qBt_webui/public - - - - ${cfg.alternativeWebUI.package}/share/vuetorrent"
    ];

    systemd.services.qbittorrent = {
      description = "qBittorrent (nox)";
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
      allowedTCPPorts = tcpPorts;
      allowedUDPPorts = udpPorts;
    };
  };
}
