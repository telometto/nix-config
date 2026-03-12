{ VARS, ... }:
{
  sys.services = {
    paperless.enable = false;

    glance = {
      enable = true;
      port = 11064;

      reverseProxy = {
        enable = true;
        domain = "dashboard.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    actual = {
      enable = false;

      port = 11005;
      dataDir = "/rpool/unenc/apps/nixos/actual";
    };

    firefly.enable = false;
  };
}
