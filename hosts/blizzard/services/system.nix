{ VARS, consts, ... }:
{
  sys.services = {
    scrutiny = {
      enable = true;

      port = consts.ports.host.scrutiny;
      openFirewall = true;

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
