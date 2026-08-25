{ VARS, consts, ... }:
{
  sys.services = {
    paperless.enable = false;

    glance = {
      enable = true;
      port = consts.ports.host.glance;

      reverseProxy = {
        enable = true;
        domain = "dashboard.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    actual = {
      enable = false;

      port = consts.ports.host.actual;
      dataDir = "/rpool/unenc/apps/nixos/actual";
    };

    firefly.enable = false;
  };
}
