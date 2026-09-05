{
  blizzard,
  pkgs,
}:
let
  inherit (pkgs) lib;
  cfg = blizzard.config;
  static = cfg.services.traefik.staticConfigOptions;
  bouncer = cfg.services.traefik.dynamicConfigOptions.http.middlewares.crowdsec.plugin.bouncer;
  trustedIPs = [
    "127.0.0.1/32"
    "::1/128"
  ];
  acquisitions = lib.filter (
    acquisition: (acquisition.labels.type or null) == "traefik"
  ) cfg.services.crowdsec.localConfig.acquisitions;
  acquisition = builtins.head acquisitions;
  # Project the effective production contracts, without plugins, credentials,
  # real routes, or external certificate/provider dependencies. The runtime
  # test changes only listener addresses and supplies a local fixture backend.
  settings = pkgs.writeText "crowdsec-http-settings.json" (
    builtins.toJSON {
      inherit (static) accessLog;
      entryPoints = {
        inherit (static.entryPoints) web websecure;
      };
    }
  );
in
assert cfg.services.crowdsec.enable;
assert cfg.services.traefik.enable;
assert builtins.length acquisitions == 1;
assert acquisition.source == "journalctl";
assert
  acquisition.journalctl_filter == [
    "_SYSTEMD_UNIT=traefik.service"
    "--output=cat"
  ];
assert lib.elem pkgs.systemd cfg.systemd.services.crowdsec.path;
assert static.accessLog.format == "json";
assert static.accessLog.fields.headers.defaultMode == "drop";
assert static.accessLog.fields.headers.names == { User-Agent = "keep"; };
assert lib.all
  (
    name:
    static.entryPoints.${name}.forwardedHeaders.trustedIPs == trustedIPs
    && static.entryPoints.${name}.forwardedHeaders.insecure == false
  )
  [
    "web"
    "websecure"
  ];
assert bouncer.forwardedHeadersTrustedIPs == trustedIPs;
assert (bouncer.forwardedHeadersCustomName or "X-Forwarded-For") == "X-Forwarded-For";
pkgs.runCommand "crowdsec-http-tests"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python ${./crowdsec_http.py} \
      --traefik ${lib.getExe cfg.services.traefik.package} \
      --settings ${settings}
    touch "$out"
  ''
