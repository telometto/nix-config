{
  config,
  consts,
  lib,
  pkgs,
  ...
}:
let
  registry = import ../../../vms/vm-registry.nix { inherit consts; };
  networkDefaults = import ../../../vms/microvm-network-defaults.nix;
  paperlessEnabled = config.sys.virtualisation.microvm.instances.paperless.enable or false;
  # Some paths are subdirectories rather than dataset roots. Check ancestry
  # so a guessed filehandle cannot grant access outside the selected export.
  clientOptions = "rw,sync,root_squash,subtree_check,secure";
  client = address: "${address}(${clientOptions})";
  firewallReady = "${pkgs.systemd}/bin/systemctl --quiet is-active firewall.service";
  firewall = import ../../../lib/nfs-firewall.nix {
    inherit lib;
    serverIPv4 = consts.tailscale.hosts.blizzard.ipv4;
    tailscaleClients = with consts.tailscale.hosts; [
      snowfall.ipv4
      avalanche.ipv4
    ];
    paperless =
      if paperlessEnabled then
        {
          inherit (registry.paperless) ip;
          bridge = networkDefaults.sharedBridge.name;
          gateway = networkDefaults.sharedBridge.address;
        }
      else
        null;
    auxiliaryPorts = with config.sys.services.nfs.server; [
      111
      statdPort
      lockdPort
      mountdPort
    ];
  };
in
{
  sys.services.nfs = {
    enable = true;
    server = {
      enable = true;
      openFirewall = false;
      exports = ''
        /rpool/enc/transfers ${client consts.tailscale.hosts.snowfall.ipv4} ${client consts.tailscale.hosts.avalanche.ipv4}
        /rpool/unenc/media/data/media ${client consts.tailscale.hosts.snowfall.ipv4}
      ''
      + lib.optionalString paperlessEnabled ''
        /flash/enc/personal/paperless-consumption ${client registry.paperless.ip}
      '';
    };
  };

  # NFSv4 needs only TCP 2049. Legacy RPC daemons remain inaccessible even
  # when Tailscale installs its own earlier INPUT accept rule.
  services.nfs.settings.nfsd = {
    vers3 = false;
    vers4 = true;
    udp = false;
    tcp = true;
  };
  networking.firewall = {
    inherit (firewall) extraCommands extraStopCommands;
  };

  # Socket activation must not get ahead of the raw guard on the first boot.
  # Wants/After keep a routine firewall restart from stopping NFS; the raw
  # stop guard denies connections until the replacement rules are complete.
  systemd.services = {
    nfs-firewall-ready = {
      description = "Require the guarded firewall before starting NFS listeners";
      wants = [ "firewall.service" ];
      after = [ "firewall.service" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = firewallReady;
        RemainAfterExit = true;
      };
    };
  }
  // lib.genAttrs [ "nfs-server" "nfs-mountd" "rpc-statd" "rpcbind" ] (_: {
    wants = [ "firewall.service" ];
    after = [
      "firewall.service"
      "nfs-firewall-ready.service"
    ];
    requires = [ "nfs-firewall-ready.service" ];
    serviceConfig.ExecStartPre = [ firewallReady ];
  });
  systemd.sockets.rpcbind = {
    wants = [ "firewall.service" ];
    after = [
      "firewall.service"
      "nfs-firewall-ready.service"
    ];
    requires = [ "nfs-firewall-ready.service" ];
  };
  assertions = [
    {
      assertion = config.networking.firewall.enable && config.networking.firewall.backend == "iptables";
      message = "Blizzard NFS requires the iptables firewall and its source/interface guard";
    }
    {
      assertion = config.services.tailscale.enable;
      message = "Blizzard's named NFS host clients require Tailscale";
    }
    {
      assertion = !config.sys.services.nfs.server.openFirewall;
      message = "Blizzard NFS must not open global NFS/RPC firewall ports";
    }
  ];
}
