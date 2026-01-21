{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sys.services.webzfs;

  webzfsPackage = pkgs.stdenv.mkDerivation rec {
    pname = "webzfs";
    version = "0.5.2";

    src = pkgs.fetchFromGitHub {
      owner = "webzfs";
      repo = "webzfs";
      rev = "c930c3fad5a20cb6ad04e8ae52c81c2a13b3a47f";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    nativeBuildInputs = with pkgs; [
      python311
      python311Packages.pip
      python311Packages.virtualenv
      nodejs_20
      nodePackages.npm
    ];

    buildInputs = with pkgs; [
      zfs
      smartmontools
    ];

    configurePhase = ''
      export HOME=$TMPDIR
    '';

    buildPhase = ''
      python -m venv .venv
      source .venv/bin/activate
      pip install --no-cache-dir -r requirements.txt
      npm install
      npm run build
    '';

    installPhase = ''
      mkdir -p $out/opt/webzfs
      cp -r . $out/opt/webzfs/

      mkdir -p $out/bin
      cat > $out/bin/webzfs <<EOF
      #!${pkgs.bash}/bin/bash
      cd $out/opt/webzfs
      exec $out/opt/webzfs/.venv/bin/python -m uvicorn src.main:app --host \''${WEBZFS_HOST:-127.0.0.1} --port \''${WEBZFS_PORT:-26619}
      EOF
      chmod +x $out/bin/webzfs
    '';

    meta = with lib; {
      description = "Modern web-based management interface for ZFS";
      homepage = "https://github.com/webzfs/webzfs";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = [ ];
    };
  };

  webzfsUser = "webzfs";
  webzfsGroup = "webzfs";
in
{
  options.sys.services.webzfs = {
    enable = lib.mkEnableOption "WebZFS - ZFS web management interface";

    package = lib.mkOption {
      type = lib.types.package;
      default = webzfsPackage;
      description = "The webzfs package to use";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 26619;
      description = "Port to listen on";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for WebZFS port";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/webzfs";
      description = "Directory for WebZFS data";
    };

    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Secret key for session management. Change this in production!";
    };

    extraZfsPermissions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "create"
        "destroy"
        "mount"
        "snapshot"
        "rollback"
        "clone"
        "promote"
        "rename"
        "send"
        "receive"
      ];
      description = "ZFS permissions to delegate to webzfs user";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${webzfsUser} = {
      isSystemUser = true;
      group = webzfsGroup;
      home = cfg.dataDir;
      createHome = true;
      description = "WebZFS service user";
    };

    users.groups.${webzfsGroup} = { };

    environment.systemPackages = [ cfg.package ];

    systemd.services.webzfs = {
      description = "WebZFS - ZFS Web Management Interface";
      after = [
        "network.target"
        "zfs.target"
      ];
      wants = [ "zfs.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        WEBZFS_HOST = cfg.host;
        WEBZFS_PORT = toString cfg.port;
        WEBZFS_DATA_DIR = cfg.dataDir;
        SECRET_KEY = cfg.secretKey;
      };

      serviceConfig = {
        Type = "simple";
        User = webzfsUser;
        Group = webzfsGroup;
        WorkingDirectory = "${cfg.package}/opt/webzfs";
        ExecStart = "${cfg.package}/bin/webzfs";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        ProtectKernelTunables = false;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;

        CapabilityBoundingSet = [
          "CAP_DAC_READ_SEARCH"
          "CAP_SYS_ADMIN"
        ];
        AmbientCapabilities = [
          "CAP_DAC_READ_SEARCH"
          "CAP_SYS_ADMIN"
        ];
      };
    };

    security.sudo.extraRules = [
      {
        users = [ webzfsUser ];
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
            command = "${pkgs.zfs}/bin/zdb";
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
