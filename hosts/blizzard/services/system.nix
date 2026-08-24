{ VARS, consts, ... }:
{
  sys.services = {
    scrutiny = {
      enable = true;

      port = consts.scrutinyPort;
      openFirewall = true;

      reverseProxy = {
        enable = false;
        domain = "scrutiny.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    cockpit = {
      enable = false;
      port = consts.cockpitPort;
      openFirewall = true;
    };
  };
}
