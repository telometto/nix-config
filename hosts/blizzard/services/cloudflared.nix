{ config, VARS, ... }:
{
  sys.services.cloudflared = {
    enable = true;

    tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
    credentialsFile = config.sys.secrets.cloudflaredCredentialsFile;

    # Standard MicroVM publications are rendered from microvms.nix. Only
    # host-level services and ingress needed by bespoke path routes belong here.
    ingress = {
      "dashboard.${VARS.domains.public}" = "http://localhost:80";
      "metrics.${VARS.domains.public}" = "http://localhost:80";
      "lingarr.${VARS.domains.public}" = "http://localhost:80";
      "nominatim.${VARS.domains.public}" = "http://localhost:80";
      # Matrix's root-domain discovery route shares this host-level ingress.
      # The matrix.<domain> workload route is a managed MicroVM publication.
      "${VARS.domains.public}" = "http://localhost:80";
    };
  };
}
