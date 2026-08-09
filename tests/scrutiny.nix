{ blizzard, pkgs }:
let
  inherit (pkgs) lib;
  cfg = blizzard.config;
  tokenPath = cfg.sops.secrets."scrutiny/token".path;
  scrutinyService = cfg.systemd.services.scrutiny;
  disabled = blizzard.extendModules {
    modules = [
      {
        sys.services.scrutiny.enable = lib.mkForce false;
      }
    ];
  };
in
assert cfg.sys.secrets.scrutinyTokenFile == tokenPath;
assert cfg.sops.secrets."scrutiny/token".mode == "0400";
assert cfg.sops.secrets."scrutiny/token".owner == "root";
assert cfg.services.scrutiny.settings.web.influxdb.host == "127.0.0.1";
assert cfg.services.scrutiny.collector.settings.api.endpoint == "http://127.0.0.1:11001";
assert scrutinyService.serviceConfig.LoadCredential == "scrutiny-token:${tokenPath}";
assert lib.elem "sops-install-secrets.service" scrutinyService.requires;
assert lib.elem "sops-install-secrets.service" scrutinyService.after;
assert lib.hasInfix "scrutiny-with-token" scrutinyService.serviceConfig.ExecStart;
assert cfg.services.scrutiny.settings.web.influxdb.token == null;
assert !(disabled.config.sops.secrets ? "scrutiny/token");
pkgs.runCommand "scrutiny-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  grep -Fq '$CREDENTIALS_DIRECTORY/scrutiny-token' ${scrutinyService.serviceConfig.ExecStart}
  grep -Fq 'SCRUTINY_WEB_INFLUXDB_TOKEN' ${scrutinyService.serviceConfig.ExecStart}
  touch "$out"
''
