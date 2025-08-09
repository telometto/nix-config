# Central shared constants to avoid scattering literals
{
  network = {
    lanCIDR = "192.168.2.0/24";
    nfsServerIP = "192.168.2.100";
  };

  tailscale = {
    routeCIDR = "192.168.2.0/24"; # same as lanCIDR; keep separate for flexibility
  };

  nfs = {
    transfersExport = "/rpool/enc/transfers"; # server-side export path
  };

  backups = {
    blizzardRepo = "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
    blizzardKeyFile = "/opt/sec/borg-file"; # passCommand target
  };
}
