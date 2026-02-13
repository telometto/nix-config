_:
{
  sys.services.samba = {
    enable = false;
    openFirewall = true;

    shares.destroyme = {
      path = "/rpool/unenc/destroyme";
      forceUser = "zeno";
    };
  };
}
