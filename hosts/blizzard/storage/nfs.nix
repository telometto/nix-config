{ lib, ... }:
{
  sys.services.nfs = {
    enable = true;
    server = {
      enable = true;
      openFirewall = lib.mkForce true;
      exports = ''
        /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
        /rpool/unenc/media/data 10.100.0.0/24(rw,sync,nohide,no_subtree_check)
      '';
    };
  };
}
