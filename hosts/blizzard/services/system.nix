{
  config,
  VARS,
  consts,
  ...
}:
{
  sys.services = {
    # Keep the shared home-IP bypass under one always-on writer. Desktop writers
    # can roam onto untrusted NATs and must not republish those addresses.
    cloudflareAccessIpUpdater = {
      enable = true;
      accountIdFile = config.sys.secrets.cloudflareAccountIdFile;
      policyIdFile = config.sys.secrets.cloudflarePolicyIdFile;
      apiTokenFile = config.sys.secrets.cloudflareAccessApiTokenFile;
      interval = "30min";
    };

    scrutiny = {
      enable = true;

      port = consts.ports.host.scrutiny;
      openFirewall = false;

      reverseProxy = {
        enable = false;
        domain = "scrutiny.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    cockpit = {
      enable = false;
      port = consts.ports.host.cockpit;
      openFirewall = true;
    };
  };
}
