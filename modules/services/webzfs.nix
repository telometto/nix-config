{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.sys.services.webzfs;
in
{
  options.sys.services.webzfs = {
    enable = lib.mkEnableOption "WebZFS web management interface";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to. Default is localhost only.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 26619;
      description = "Port to listen on. Default is 26619 (Z=26 + F=6 + S=19).";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the SECRET_KEY. If not set, a random key will be generated on first start.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the configured port.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.webzfs = {
      isSystemUser = true;
      group = "webzfs";
      description = "WebZFS service user";
    };

    users.groups.webzfs = { };

    systemd.services.webzfs = {
      description = "WebZFS - ZFS Web Management Interface";
      after = [
        "network.target"
        "zfs.target"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "webzfs";
        Group = "webzfs";
        WorkingDirectory = "${pkgs.webzfs}/opt/webzfs";
        ExecStart = "${pkgs.webzfs}/bin/webzfs";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/webzfs" ];

        # Environment
        Environment = [
          "HOST=${cfg.host}"
          "PORT=${toString cfg.port}"
          "PATH=${
            lib.makeBinPath [
              pkgs.zfs
              pkgs.smartmontools
              pkgs.sanoid
              pkgs.coreutils
              pkgs.util-linux
              pkgs.sudo
            ]
          }:/run/current-system/sw/bin"
        ];
      };

      preStart = ''
        mkdir -p /var/lib/webzfs
        chown webzfs:webzfs /var/lib/webzfs

        # Generate or copy SECRET_KEY
        if [ ! -f /var/lib/webzfs/.env ]; then
          cp ${pkgs.webzfs}/opt/webzfs/.env /var/lib/webzfs/.env
          ${
            if cfg.secretKeyFile != null then
              ''
                SECRET_KEY=$(cat ${cfg.secretKeyFile})
                sed -i "s|^SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|" /var/lib/webzfs/.env
              ''
            else
              ""
          }
          chown webzfs:webzfs /var/lib/webzfs/.env
        fi

        ln -sf /var/lib/webzfs/.env ${pkgs.webzfs}/opt/webzfs/.env
      '';
    };

    # Configure sudo permissions for webzfs user to run ZFS commands
    security.sudo.extraRules = [
      {
        users = [ "webzfs" ];
        commands = [
          {
            command = "${pkgs.zfs}/bin/zpool";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.zfs}/bin/zfs";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.smartmontools}/bin/smartctl";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
