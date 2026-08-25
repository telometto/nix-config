{ VARS, consts, ... }:
{
  sys.services = {
    plex = {
      enable = true;
      openFirewall = true;
    };

    jellyfin = {
      enable = false;

      openFirewall = true;

      reverseProxy = {
        enable = true;

        pathPrefix = "/jellyfin";
        stripPrefix = false;
      };
    };

    ombi = {
      enable = false;

      port = consts.ports.host.ombi;
      openFirewall = true;
      dataDir = "/rpool/unenc/apps/nixos/ombi";

      reverseProxy = {
        enable = true;
        domain = "ombi.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    tautulli = {
      enable = false;

      port = consts.ports.host.tautulli;
      openFirewall = true;
      dataDir = "/rpool/unenc/apps/nixos/tautulli";

      reverseProxy = {
        enable = true;
        domain = "tautulli.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };
  };
}
