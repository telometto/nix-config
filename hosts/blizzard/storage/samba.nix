{ ... }:
{
  sys.services.samba = {
    enable = true;
    openFirewall = true;

    shares.destroyme = {
      path = "/rpool/unenc/destroyme";
      forceUser = "zeno";
    };
  };
}
