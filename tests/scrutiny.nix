{ blizzard, pkgs }:
let
  inherit (pkgs) lib;
  cfg = blizzard.config;
  tokenPath = cfg.sops.secrets."scrutiny/token".path;
  tokenEnvironmentPath = cfg.sops.templates."scrutiny-environment".path;
  tokenEnvironmentContent = cfg.sops.templates."scrutiny-environment".content;
  scrutinyService = cfg.systemd.services.scrutiny;
  disabled = blizzard.extendModules {
    modules = [
      {
        sys.services.scrutiny.enable = lib.mkForce false;
      }
    ];
  };
  missingToken = blizzard.extendModules {
    modules = [
      {
        sys.secrets.scrutinyTokenEnvironmentFile = lib.mkForce null;
      }
    ];
  };
in
assert cfg.sys.secrets.scrutinyTokenFile == tokenPath;
assert cfg.sys.secrets.scrutinyTokenEnvironmentFile == tokenEnvironmentPath;
assert cfg.sops.secrets."scrutiny/token".mode == "0400";
assert cfg.sops.secrets."scrutiny/token".owner == "root";
assert cfg.sops.templates."scrutiny-environment".mode == "0400";
assert cfg.sops.templates."scrutiny-environment".owner == "root";
assert lib.elem "scrutiny.service" cfg.sops.secrets."scrutiny/token".restartUnits;
assert cfg.services.scrutiny.settings.web.influxdb.host == "127.0.0.1";
assert
  cfg.services.scrutiny.collector.settings.api.endpoint
  == "http://127.0.0.1:${toString cfg.sys.services.scrutiny.port}";
assert scrutinyService.serviceConfig.EnvironmentFile == [ tokenEnvironmentPath ];
assert lib.elem "sops-install-secrets.service" scrutinyService.requires;
assert lib.elem "sops-install-secrets.service" scrutinyService.after;
assert cfg.services.scrutiny.settings.web.influxdb.token == null;
assert !(disabled.config.sops.secrets ? "scrutiny/token");
assert !(disabled.config.sops.templates ? "scrutiny-environment");
assert lib.hasInfix "SCRUTINY_WEB_INFLUXDB_TOKEN=" tokenEnvironmentContent;
assert lib.any (
  assertion:
  assertion.message != null
  && assertion.message == "sys.services.scrutiny requires sys.secrets.scrutinyTokenEnvironmentFile."
  && !assertion.assertion
) missingToken.config.assertions;
pkgs.runCommand "scrutiny-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  printf '%s\n' ${lib.escapeShellArg tokenEnvironmentContent} | grep -Fq 'SCRUTINY_WEB_INFLUXDB_TOKEN='
  touch "$out"
''
