{
  blizzard,
  snowfall,
  avalanche,
  kaizer,
  pkgs,
}:
let
  inherit (pkgs) lib;
  hosts = {
    inherit
      avalanche
      blizzard
      kaizer
      snowfall
      ;
  };
  enabledWriters = lib.filter (
    name: hosts.${name}.config.sys.services.cloudflareAccessIpUpdater.enable
  ) (builtins.attrNames hosts);
  blizzardConfig = blizzard.config;
  updaterUnit = blizzardConfig.systemd.services.cloudflare-access-ip-updater;
in
assert enabledWriters == [ "blizzard" ];
assert blizzardConfig.sops.useSystemdActivation;
assert builtins.hasAttr "sops-install-secrets" blizzardConfig.systemd.services;
assert lib.elem "sops-install-secrets.service" updaterUnit.after;
assert lib.elem "sops-install-secrets.service" updaterUnit.requires;
assert builtins.hasAttr "cloudflare/accountId" blizzardConfig.sops.secrets;
assert builtins.hasAttr "cloudflare/policyId" blizzardConfig.sops.secrets;
assert builtins.hasAttr "cloudflare/access_api_token" blizzardConfig.sops.secrets;
pkgs.runCommand "cloudflare-access-ip-updater-tests" { } "touch $out"
