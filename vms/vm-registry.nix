# Central registry of MicroVM network and resource allocations.
# Single source of truth - referenced by VM definitions, host expose config, and reverse proxy.
#
# Fields:
#   name         - VM short name (used for hostname "${name}-vm" and tap "vm-${name}")
#   cid          - vsock CID (must be unique, ≥ 3)
#   mac          - TAP interface MAC address (must be unique)
#   ip           - Static IP on the VM's bridge network
#   prefixLength - IPv4 prefix length (default: 24)
#   port         - Primary service port (sourced from lib/constants.nix; used by firewall, traefik, expose)
#   mem          - RAM in MiB
#   vcpu         - Virtual CPU count (default: 1)
#   gateway      - Default gateway (default: 10.100.0.1; VPN and dedicated networks override it)
#   dns          - DNS server (default: 1.1.1.1; some VMs use internal resolver 10.100.0.11)
#   tapId        - Override TAP interface name (default: "vm-${name}", needed when name is too long)
#   hostBridge   - Optional dedicated host bridge; requires gateway and is created only while enabled
{
  consts,
  ...
}:
let
  validate = import ./validate-vm-registry.nix;
in
validate {
  adguard = {
    name = "adguard";
    cid = 100;
    mac = "02:00:00:00:00:01";
    ip = "10.100.0.10";
    port = consts.ports.vm.adguard;
    mem = 3072;
    vcpu = 1;
  };

  actual = {
    name = "actual";
    cid = 101;
    mac = "02:00:00:00:00:02";
    ip = "10.100.0.51";
    port = consts.ports.vm.actual;
    mem = 1024;
    vcpu = 1;
  };

  searx = {
    name = "searx";
    cid = 102;
    mac = "02:00:00:00:00:03";
    ip = "10.100.0.12";
    port = consts.ports.vm.searx;
    mem = 2048;
    vcpu = 1;
  };

  ombi = {
    name = "ombi";
    cid = 104;
    mac = "02:00:00:00:00:05";
    ip = "10.100.0.41";
    port = consts.ports.vm.ombi;
    mem = 1024;
    vcpu = 1;
  };

  tautulli = {
    name = "tautulli";
    cid = 105;
    mac = "02:00:00:00:00:06";
    ip = "10.100.0.42";
    port = consts.ports.vm.tautulli;
    mem = 1024;
    vcpu = 1;
  };

  gitea = {
    name = "gitea";
    cid = 106;
    mac = "02:00:00:00:00:07";
    ip = "10.100.0.50";
    port = consts.ports.vm.gitea;
    mem = 2048;
    vcpu = 2;
  };

  sonarr = {
    name = "sonarr";
    cid = 107;
    mac = "02:00:00:00:00:08";
    ip = "10.100.0.21";
    port = consts.ports.vm.sonarr;
    mem = 1024;
    vcpu = 1;
  };

  radarr = {
    name = "radarr";
    cid = 108;
    mac = "02:00:00:00:00:09";
    ip = "10.100.0.22";
    port = consts.ports.vm.radarr;
    mem = 1024;
    vcpu = 1;
  };

  prowlarr = {
    name = "prowlarr";
    cid = 109;
    mac = "02:00:00:00:00:0A";
    ip = "10.100.0.20";
    port = consts.ports.vm.prowlarr;
    mem = 1024;
    vcpu = 1;
  };

  bazarr = {
    name = "bazarr";
    cid = 110;
    mac = "02:00:00:00:00:0B";
    ip = "10.100.0.23";
    port = consts.ports.vm.bazarr;
    mem = 1024;
    vcpu = 1;
  };

  readarr = {
    name = "readarr";
    cid = 111;
    mac = "02:00:00:00:00:0C";
    ip = "10.100.0.24";
    port = consts.ports.vm.readarr;
    mem = 1024;
    vcpu = 1;
  };

  lidarr = {
    name = "lidarr";
    cid = 112;
    mac = "02:00:00:00:00:0D";
    ip = "10.100.0.26";
    port = consts.ports.vm.lidarr;
    mem = 1024;
    vcpu = 1;
  };

  qbittorrent = {
    name = "qbittorrent";
    cid = 113;
    mac = "02:00:00:00:00:0E";
    ip = "10.100.0.30";
    port = consts.ports.vm.qbittorrent;
    mem = 2048;
    vcpu = 1;
    gateway = "10.100.0.11";
    dns = "10.100.0.11";
  };

  overseerr = {
    name = "overseerr";
    cid = 114;
    mac = "02:00:00:00:00:0F";
    ip = "10.100.0.40";
    port = consts.ports.vm.overseerr;
    mem = 1024;
    vcpu = 1;
  };

  firefox = {
    name = "firefox";
    cid = 115;
    mac = "02:00:00:00:00:10";
    ip = "10.100.0.52";
    port = consts.ports.vm.firefox;
    mem = 4096;
    vcpu = 4;
    gateway = "10.100.0.11";
  };

  wireguard = {
    name = "wireguard";
    cid = 116;
    mac = "02:00:00:00:00:11";
    ip = "10.100.0.11";
    port = consts.ports.vm.wireguard;
    mem = 512;
    vcpu = 1;
  };

  sabnzbd = {
    name = "sabnzbd";
    cid = 117;
    mac = "02:00:00:00:00:12";
    ip = "10.100.0.31";
    port = consts.ports.vm.sabnzbd;
    mem = 1024;
    vcpu = 1;
    gateway = "10.100.0.11";
    dns = "10.100.0.11";
  };

  # Reserved for the flaresolverr service embedded in prowlarr-vm.
  # This is not wired as a standalone flake output by design.
  flaresolverr = {
    name = "flaresolverr";
    cid = 118;
    mac = "02:00:00:00:00:13";
    ip = "10.100.0.13";
    port = consts.ports.vm.flaresolverr;
    mem = 512;
    vcpu = 1;
  };

  "matrix-synapse" = {
    name = "matrix-synapse";
    cid = 119;
    mac = "02:00:00:00:00:14";
    ip = "10.100.0.60";
    port = consts.ports.vm.matrixSynapse;
    mem = 4096;
    vcpu = 4;
    tapId = "vm-matrix";
  };

  paperless = {
    name = "paperless";
    cid = 120;
    mac = "02:00:00:00:00:15";
    ip = "10.100.0.61";
    port = consts.ports.vm.paperless;
    mem = 8192;
    vcpu = 4;
    tapId = "vm-paperless";
  };

  firefly = {
    name = "firefly";
    cid = 121;
    mac = "02:00:00:00:00:16";
    ip = "10.100.0.62";
    port = consts.ports.vm.firefly;
    mem = 2048;
    vcpu = 2;
  };

  brave = {
    name = "brave";
    cid = 122; # Fixed: was 116 (conflicted with wireguard)
    mac = "02:00:00:00:00:17"; # Fixed: was 11 (conflicted with wireguard)
    ip = "10.100.0.54";
    port = consts.ports.vm.brave;
    mem = 4096;
    vcpu = 4;
    gateway = "10.100.0.11";
  };

  "firefly-importer" = {
    name = "firefly-importer";
    cid = 123;
    mac = "02:00:00:00:00:18";
    ip = "10.100.0.63";
    port = consts.ports.vm.fireflyImporter;
    mem = 512;
    vcpu = 1;
    tapId = "vm-ff-import";
  };

  immich = {
    name = "immich";
    cid = 124;
    mac = "02:00:00:00:00:19";
    ip = "10.100.0.70";
    port = consts.ports.vm.immich;
    mem = 8192;
    vcpu = 4;
  };

  mealie = {
    name = "mealie";
    cid = 125;
    mac = "02:00:00:00:00:1A";
    ip = "10.100.0.71";
    port = consts.ports.vm.mealie;
    mem = 1024;
    vcpu = 1;
  };

  trigger = {
    name = "trigger";
    cid = 126;
    mac = "02:00:00:00:00:1B";
    ip = "10.100.0.80";
    port = consts.ports.vm.trigger;
    mem = 12288;
    vcpu = 6;
  };

  "pocket-id" = {
    name = "pocket-id";
    cid = 127;
    mac = "02:00:00:00:00:1C";
    ip = "10.100.1.2";
    prefixLength = 30;
    gateway = "10.100.1.1";
    hostBridge = "pocket-id-br0";
    port = consts.ports.vm.pocketId;
    mem = 1024;
    vcpu = 1;
  };
}
