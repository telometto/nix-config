{ VARS, consts, ... }:
{
  sys.services = {
    paperless.enable = false;

    glance = {
      enable = true;
      port = consts.glancePort;

      reverseProxy = {
        enable = true;
        domain = "dashboard.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    actual = {
      enable = false;

      port = consts.actualHostPort;
      dataDir = "/rpool/unenc/apps/nixos/actual";
    };

    firefly.enable = false;
  };
}
