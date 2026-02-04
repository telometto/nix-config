{ VARS, ... }:
{
  sys.services = {scrutiny = {
    enable = true;
    port = 11001;
    openFirewall = true;

    reverseProxy = {
      enable = false;
      domain = "scrutiny.${VARS.domains.public}";
      cfTunnel.enable = true;
    };
  };

  cockpit = {
    enable = false;
    port = 11006;
    openFirewall = true;
  };};
}
