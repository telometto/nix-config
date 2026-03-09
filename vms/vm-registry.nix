# Central registry of MicroVM network and resource allocations.
# Single source of truth — referenced by VM definitions, host expose config, and reverse proxy.
#
# Fields:
#   name     — VM short name (used for hostname "${name}-vm" and tap "vm-${name}")
#   cid      — vsock CID (must be unique, ≥ 3)
#   mac      — TAP interface MAC address (must be unique)
#   ip       — Static IP on the 10.100.0.0/24 bridge network
#   port     — Primary service port (used by firewall, traefik, expose)
#   mem      — RAM in MiB
#   vcpu     — Virtual CPU count (default: 1)
#   gateway  — Default gateway (default: 10.100.0.1; VPN-routed VMs use 10.100.0.11)
#   dns      — DNS server (default: 1.1.1.1; some VMs use internal resolver 10.100.0.11)
#   tapId    — Override TAP interface name (default: "vm-${name}", needed when name is too long)
{
  adguard = {
    name = "adguard";
    cid = 100;
    mac = "02:00:00:00:00:01";
    ip = "10.100.0.10";
    port = 11010;
    mem = 3072;
    vcpu = 1;
  };

  actual = {
    name = "actual";
    cid = 101;
    mac = "02:00:00:00:00:02";
    ip = "10.100.0.51";
    port = 11051;
    mem = 1024;
    vcpu = 1;
  };

  searx = {
    name = "searx";
    cid = 102;
    mac = "02:00:00:00:00:03";
    ip = "10.100.0.12";
    port = 11012;
    mem = 2048;
    vcpu = 1;
  };

  ombi = {
    name = "ombi";
    cid = 104;
    mac = "02:00:00:00:00:05";
    ip = "10.100.0.41";
    port = 11041;
    mem = 1024;
    vcpu = 1;
  };

  tautulli = {
    name = "tautulli";
    cid = 105;
    mac = "02:00:00:00:00:06";
    ip = "10.100.0.42";
    port = 11042;
    mem = 1024;
    vcpu = 1;
  };

  gitea = {
    name = "gitea";
    cid = 106;
    mac = "02:00:00:00:00:07";
    ip = "10.100.0.50";
    port = 11050;
    mem = 2048;
    vcpu = 2;
  };

  sonarr = {
    name = "sonarr";
    cid = 107;
    mac = "02:00:00:00:00:08";
    ip = "10.100.0.21";
    port = 11021;
    mem = 1024;
    vcpu = 1;
  };

  radarr = {
    name = "radarr";
    cid = 108;
    mac = "02:00:00:00:00:09";
    ip = "10.100.0.22";
    port = 11022;
    mem = 1024;
    vcpu = 1;
  };

  prowlarr = {
    name = "prowlarr";
    cid = 109;
    mac = "02:00:00:00:00:0A";
    ip = "10.100.0.20";
    port = 11020;
    mem = 1024;
    vcpu = 1;
  };

  bazarr = {
    name = "bazarr";
    cid = 110;
    mac = "02:00:00:00:00:0B";
    ip = "10.100.0.23";
    port = 11023;
    mem = 1024;
    vcpu = 1;
  };

  readarr = {
    name = "readarr";
    cid = 111;
    mac = "02:00:00:00:00:0C";
    ip = "10.100.0.24";
    port = 11024;
    mem = 1024;
    vcpu = 1;
  };

  lidarr = {
    name = "lidarr";
    cid = 112;
    mac = "02:00:00:00:00:0D";
    ip = "10.100.0.26";
    port = 11028;
    mem = 1024;
    vcpu = 1;
  };

  qbittorrent = {
    name = "qbittorrent";
    cid = 113;
    mac = "02:00:00:00:00:0E";
    ip = "10.100.0.30";
    port = 11030;
    mem = 1024;
    vcpu = 1;
    gateway = "10.100.0.11";
    dns = "10.100.0.11";
  };

  overseerr = {
    name = "overseerr";
    cid = 114;
    mac = "02:00:00:00:00:0F";
    ip = "10.100.0.40";
    port = 11040;
    mem = 1024;
    vcpu = 1;
  };

  firefox = {
    name = "firefox";
    cid = 115;
    mac = "02:00:00:00:00:10";
    ip = "10.100.0.52";
    port = 11052;
    mem = 4096;
    vcpu = 4;
    gateway = "10.100.0.11";
  };

  wireguard = {
    name = "wireguard";
    cid = 116;
    mac = "02:00:00:00:00:11";
    ip = "10.100.0.11";
    port = 56943;
    mem = 512;
    vcpu = 1;
  };

  sabnzbd = {
    name = "sabnzbd";
    cid = 117;
    mac = "02:00:00:00:00:12";
    ip = "10.100.0.31";
    port = 11031;
    mem = 1024;
    vcpu = 1;
    gateway = "10.100.0.11";
    dns = "10.100.0.11";
  };

  flaresolverr = {
    name = "flaresolverr";
    cid = 118;
    mac = "02:00:00:00:00:13";
    ip = "10.100.0.13";
    port = 11013;
    mem = 512;
    vcpu = 1;
  };

  "matrix-synapse" = {
    name = "matrix-synapse";
    cid = 119;
    mac = "02:00:00:00:00:14";
    ip = "10.100.0.60";
    port = 11060;
    mem = 4096;
    vcpu = 4;
    tapId = "vm-matrix";
  };

  paperless = {
    name = "paperless";
    cid = 120;
    mac = "02:00:00:00:00:15";
    ip = "10.100.0.61";
    port = 11061;
    mem = 8192;
    vcpu = 4;
    tapId = "vm-paperless";
  };

  firefly = {
    name = "firefly";
    cid = 121;
    mac = "02:00:00:00:00:16";
    ip = "10.100.0.62";
    port = 11062;
    mem = 2048;
    vcpu = 2;
  };

  brave = {
    name = "brave";
    cid = 122; # Fixed: was 116 (conflicted with wireguard)
    mac = "02:00:00:00:00:17"; # Fixed: was 11 (conflicted with wireguard)
    ip = "10.100.0.54";
    port = 11054;
    mem = 4096;
    vcpu = 4;
    gateway = "10.100.0.11";
  };

  "firefly-importer" = {
    name = "firefly-importer";
    cid = 123;
    mac = "02:00:00:00:00:18";
    ip = "10.100.0.63";
    port = 11063;
    mem = 512;
    vcpu = 1;
    tapId = "vm-ff-import";
  };
}
