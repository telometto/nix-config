# Exercise the SOPS declarations without reading any SOPS document.
{ pkgs }:
let
  inherit (pkgs) lib;
  declaration =
    {
      server ? false,
      split ? false,
      scoped ? true,
    }:
    import ../modules/core/sops.nix {
      inherit pkgs lib;
      inputs.nix-secrets.secrets.secretsFile = "/fixture/shared.yaml";
      config = {
        networking.hostName = if server then "blizzard" else "snowfall";
        services = {
          borgbackup.jobs = { };
          prometheus.enable = true;
        };
        sys = {
          secrets.victoriametricsSopsFile = if scoped then "/fixture/host.yaml" else null;
          services = {
            victoriametrics = {
              enable = server;
              authorization.enable = split;
            };
            victoriametricsRemoteWrite.enable = !server;
          };
        };
        sops.defaultSopsFile = "/fixture/shared.yaml";
      };
    };
  server = declaration {
    server = true;
    split = true;
  };
  writer = declaration { };
  legacy = declaration { scoped = false; };
  unscoped = declaration {
    server = true;
    split = true;
    scoped = false;
  };
  names = [
    "remote_write_password"
    "query_password"
    "backend_password"
  ];
in
assert lib.all (a: a.assertion) server.assertions;
assert lib.any (a: !a.assertion) unscoped.assertions;
assert lib.all (
  name: server.sops.secrets."victoriametrics/${name}".sopsFile == "/fixture/host.yaml"
) names;
assert writer.sops.secrets."victoriametrics/remote_write_password".sopsFile == "/fixture/host.yaml";
assert !(writer.sops.secrets ? "victoriametrics/query_password");
assert !(writer.sops.secrets ? "victoriametrics/backend_password");
assert !(legacy.sops.secrets."victoriametrics/remote_write_password" ? sopsFile);
assert
  server.sops.secrets."victoriametrics/remote_write_password".group == "monitoring-credentials";
assert server.sops.secrets."victoriametrics/remote_write_password".mode == "0440";
assert lib.all
  (
    name:
    let
      secret = server.sops.secrets."victoriametrics/${name}";
    in
    secret.owner == "root" && secret.group == "root" && secret.mode == "0400"
  )
  [
    "query_password"
    "backend_password"
  ];
assert lib.all (
  name:
  let
    units = server.sops.secrets."victoriametrics/${name}".restartUnits;
  in
  lib.elem "victoriametrics.service" units && lib.elem "victoriametrics-vmauth.service" units
) names;
assert lib.elem "grafana.service" server.sops.secrets."victoriametrics/query_password".restartUnits;
assert lib.elem "prometheus.service"
  server.sops.secrets."victoriametrics/remote_write_password".restartUnits;
pkgs.runCommand "metrics-secret-declarations" { } ''
  touch "$out"
''
