{ config, VARS, ... }:
{
  sys.services.cloudflared = {
    enable = true;

    tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
    credentialsFile = config.sys.secrets.cloudflaredCredentialsFile;

    # VM-specific tunnel routes are declared per-VM via cfTunnel in microvms.nix.
    # Only host-level services that are not managed by a MicroVM belong here.
    ingress = {
      "metrics.${VARS.domains.public}" = "http://localhost:80";
      "lingarr.${VARS.domains.public}" = "http://localhost:80";
    };
  };
}
