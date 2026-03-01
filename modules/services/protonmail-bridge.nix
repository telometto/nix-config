{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.protonmail-bridge;
in
{
  options.sys.services.protonmail-bridge = {
    enable = lib.mkEnableOption "Proton Mail Bridge (localhost IMAP/SMTP proxy for Proton Mail)";

    package = lib.mkPackageOption pkgs "protonmail-bridge" { };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "panic"
        "fatal"
        "error"
        "warn"
        "info"
        "debug"
      ];
      default = "info";
      description = "Log level for the Proton Mail Bridge daemon";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/protonmail-bridge";
      description = "Persistent state directory (credentials, config, cache)";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-level service for headless operation.
    # The upstream NixOS module (services.protonmail-bridge) creates a
    # user-level service targeting graphical-session, which doesn't suit
    # a headless MicroVM. This runs as a dedicated system user instead.
    systemd.services.protonmail-bridge = {
      description = "Proton Mail Bridge";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.stateDir;
        GNUPGHOME = "${cfg.stateDir}/.gnupg";
        PASSWORD_STORE_DIR = "${cfg.stateDir}/.password-store";
      };

      path = with pkgs; [
        pass
        gnupg
      ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} --noninteractive --log-level ${cfg.logLevel}";
        Restart = "always";
        RestartSec = 10;

        User = "protonmail-bridge";
        Group = "protonmail-bridge";
        StateDirectory = "protonmail-bridge";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.stateDir ];
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
    };

    users = {
      users.protonmail-bridge = {
        isSystemUser = true;
        group = "protonmail-bridge";
        home = cfg.stateDir;
        createHome = true;
      };
      groups.protonmail-bridge = { };
    };

    # Bridge CLI is needed for initial interactive login
    environment.systemPackages = [
      cfg.package
      pkgs.pass
      pkgs.gnupg
    ];
  };
}
