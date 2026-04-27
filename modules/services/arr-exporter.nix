{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.arrExporter;

  # Per-service static metadata: default port, config file sub-path, and a
  # function that produces the shell expression to extract the API key.
  serviceSpecs = {
    sonarr = {
      defaultPort = 9707;
      configSubPath = "config.xml";
      extractKey =
        configFile: ''${pkgs.gnused}/bin/sed -n 's|.*<ApiKey>\(.*\)</ApiKey>.*|\1|p' "${configFile}"'';
    };
    radarr = {
      defaultPort = 9708;
      configSubPath = "config.xml";
      extractKey =
        configFile: ''${pkgs.gnused}/bin/sed -n 's|.*<ApiKey>\(.*\)</ApiKey>.*|\1|p' "${configFile}"'';
    };
    lidarr = {
      defaultPort = 9709;
      configSubPath = "config.xml";
      extractKey =
        configFile: ''${pkgs.gnused}/bin/sed -n 's|.*<ApiKey>\(.*\)</ApiKey>.*|\1|p' "${configFile}"'';
    };
    readarr = {
      defaultPort = 9710;
      configSubPath = "config.xml";
      extractKey =
        configFile: ''${pkgs.gnused}/bin/sed -n 's|.*<ApiKey>\(.*\)</ApiKey>.*|\1|p' "${configFile}"'';
    };
    bazarr = {
      defaultPort = 9711;
      # Bazarr stores settings in an INI file, not config.xml
      configSubPath = "config/config.ini";
      extractKey =
        configFile:
        ''${pkgs.gnused}/bin/sed -n 's/^apikey[[:space:]]*=[[:space:]]*\(.*\)/\1/p' "${configFile}" | ${pkgs.coreutils}/bin/head -1'';
    };
    prowlarr = {
      defaultPort = 9712;
      configSubPath = "config.xml";
      extractKey =
        configFile: ''${pkgs.gnused}/bin/sed -n 's|.*<ApiKey>\(.*\)</ApiKey>.*|\1|p' "${configFile}"'';
    };
  };

  mkOptions =
    name: spec:
    let
      svcCfg = config.sys.services.${name};
    in
    {
      enable = lib.mkEnableOption "${name} Prometheus exporter (exportarr)";

      port = lib.mkOption {
        type = lib.types.port;
        default = spec.defaultPort;
        description = "Port the exportarr exporter for ${name} listens on.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address the exporter binds to inside the VM.";
      };

      arrPort = lib.mkOption {
        type = lib.types.port;
        default = svcCfg.port;
        description = "Port the ${name} service listens on (used to build the exporter URL).";
      };

      configFile = lib.mkOption {
        type = lib.types.str;
        default = "${svcCfg.dataDir}/${spec.configSubPath}";
        description = "Absolute path to the ${name} config file containing the API key.";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables for the exporter (e.g. ENABLE_ADDITIONAL_METRICS=true).";
        example = {
          ENABLE_ADDITIONAL_METRICS = "true";
        };
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open a firewall port for the exporter so Prometheus can scrape it.";
      };
    };

  mkConfig =
    name: spec:
    let
      scfg = cfg.${name};
      keyseedSvc = "${name}-exporter-keyseed";
      exporterSvc = "prometheus-exportarr-${name}-exporter";
      keyFile = "/run/${name}-exporter/api-key";
    in
    lib.mkIf scfg.enable {
      # Oneshot that reads the API key from the *arr config file into a root-owned
      # tmpfs path. LoadCredential (run by PID 1) can read it regardless of
      # DynamicUser; the key never touches the Nix store.
      systemd.services.${keyseedSvc} = {
        description = "Extract API key for ${name} exportarr exporter";
        wantedBy = [ "multi-user.target" ];
        wants = [ "${name}.service" ];
        after = [ "${name}.service" ];
        before = [ "${exporterSvc}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "${name}-exporter";
          RuntimeDirectoryMode = "0700";
          ExecStart = pkgs.writeShellScript "${keyseedSvc}" ''
            set -euo pipefail
            for i in $(seq 1 60); do
              [ -s "${scfg.configFile}" ] && break
              sleep 1
            done
            key=$(${spec.extractKey scfg.configFile})
            [ -n "$key" ] || {
              echo "No API key found in ${scfg.configFile}" >&2
              exit 1
            }
            printf '%s' "$key" > "${keyFile}"
            chmod 0400 "${keyFile}"
          '';
        };
      };

      # The upstream module turns apiKeyFile into a LoadCredential entry so the
      # DynamicUser process receives the key securely via $CREDENTIALS_DIRECTORY.
      services.prometheus.exporters."exportarr-${name}" = {
        enable = true;

        inherit (scfg) port listenAddress;
        url = "http://127.0.0.1:${toString scfg.arrPort}";
        apiKeyFile = keyFile;
        environment = scfg.extraEnvironment;
      };

      systemd.services.${exporterSvc} = {
        requires = [ "${keyseedSvc}.service" ];
        after = [ "${keyseedSvc}.service" ];
      };

      networking.firewall.allowedTCPPorts = lib.mkIf scfg.openFirewall [ scfg.port ];
    };
in
{
  options.sys.services.arrExporter = lib.mapAttrs mkOptions serviceSpecs;
  config = lib.mkMerge (lib.mapAttrsToList mkConfig serviceSpecs);
}
