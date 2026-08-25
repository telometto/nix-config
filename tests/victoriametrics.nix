{
  blizzard,
  snowfall,
  pkgs,
}:
let
  inherit (pkgs) lib;
  consts = import ../lib/constants.nix;
  blizzardCfg = blizzard.config;
  snowfallCfg = snowfall.config;
  vmCfg = blizzardCfg.sys.services.victoriametrics;
  vmService = blizzardCfg.services.victoriametrics;
  vmUnit = blizzardCfg.systemd.services.victoriametrics;
  unauthenticatedRemote = blizzard.extendModules {
    modules = [
      {
        sys.services.victoriametrics.httpAuth = lib.mkForce {
          username = null;
          passwordFile = null;
        };
      }
    ];
  };
  passwordSecret = blizzardCfg.sops.secrets."victoriametrics/remote_write_password";
  passwordPath = passwordSecret.path;
  localRemoteWrite = lib.findFirst (
    entry: entry.url == "http://${vmCfg.localAddress}:${toString vmCfg.port}${vmCfg.prometheusRemoteWrite.path}"
  ) null blizzardCfg.services.prometheus.remoteWrite;
  grafanaDatasource = lib.findFirst (
    datasource: datasource.name == vmCfg.grafanaDatasource.name
  ) null blizzardCfg.sys.services.grafana.provision.datasources;
  remoteCfg = snowfallCfg.sys.services.victoriametricsRemoteWrite;
  remoteWrite = lib.findFirst (
    entry: entry.url == "http://${remoteCfg.vmHost}:${toString remoteCfg.vmPort}${remoteCfg.path}"
  ) null snowfallCfg.services.prometheus.remoteWrite;
in
assert vmCfg.listenAddress == consts.tailscale.hosts.blizzard.ipv4;
assert vmCfg.localAddress == consts.tailscale.hosts.blizzard.ipv4;
assert vmCfg.port == consts.ports.host.victoriametrics;
assert vmCfg.httpAuth.username == consts.victoriametrics.username;
assert vmCfg.httpAuth.passwordFile == passwordPath;
assert lib.any (
  assertion:
  !assertion.assertion
  && assertion.message
  == "sys.services.victoriametrics requires HTTP Basic Authentication when listenAddress is not loopback"
) unauthenticatedRemote.config.assertions;
assert passwordSecret.owner == "root";
assert passwordSecret.group == "monitoring-credentials";
assert passwordSecret.mode == "0440";
assert vmService.listenAddress == "${vmCfg.listenAddress}:${toString vmCfg.port}";
assert vmService.basicAuthUsername == consts.victoriametrics.username;
assert vmService.basicAuthPasswordFile == passwordPath;
assert lib.elem vmCfg.port blizzardCfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
assert !(lib.elem vmCfg.port blizzardCfg.networking.firewall.allowedTCPPorts);
assert lib.elem "tailscaled-autoconnect.service" vmUnit.after;
assert lib.elem "sops-install-secrets.service" vmUnit.after;
assert lib.elem "sops-install-secrets.service" vmUnit.requires;
assert lib.elem "monitoring-credentials" blizzardCfg.users.users.prometheus.extraGroups;
assert lib.elem "monitoring-credentials" blizzardCfg.users.users.grafana.extraGroups;
assert localRemoteWrite != null;
assert localRemoteWrite.basic_auth.username == consts.victoriametrics.username;
assert localRemoteWrite.basic_auth.password_file == passwordPath;
assert grafanaDatasource != null;
assert grafanaDatasource.basicAuth;
assert grafanaDatasource.basicAuthUser == consts.victoriametrics.username;
assert grafanaDatasource.secureJsonData.basicAuthPassword == "$__file{${passwordPath}}";
assert remoteCfg.vmPort == consts.ports.host.victoriametrics;
assert remoteCfg.basicAuth.username == consts.victoriametrics.username;
assert remoteCfg.basicAuth.passwordFile == snowfallCfg.sops.secrets."victoriametrics/remote_write_password".path;
assert remoteWrite != null;
assert remoteWrite.basic_auth.username == consts.victoriametrics.username;
assert remoteWrite.basic_auth.password_file == remoteCfg.basicAuth.passwordFile;
assert lib.elem "monitoring-credentials" snowfallCfg.users.users.prometheus.extraGroups;
assert lib.elem "sops-install-secrets.service" snowfallCfg.systemd.services.prometheus.requires;
pkgs.runCommand "victoriametrics-tests" { } "touch $out"
