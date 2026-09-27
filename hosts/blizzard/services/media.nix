{
  VARS,
  config,
  consts,
  jellyfinSettings,
  lib,
  pkgs,
  ...
}:
let
  jellyfinReg = (import ../../../vms/vm-registry.nix { inherit consts; }).jellyfin;
  # Keep ingress closed until the administrator wizard is finished privately.
  jellyfinVpsIPv4 = jellyfinSettings.vpsIPv4;
  jellyfinIngressReady = jellyfinSettings.vmServiceReady && jellyfinVpsIPv4 != null;
  jellyfinFirewall = import ../../../lib/jellyfin-vps-firewall.nix {
    inherit lib;
    vpsIPv4 = if jellyfinIngressReady then jellyfinVpsIPv4 else null;
  };
in
{
  sys.services = {
    plex = {
      enable = true;
      openFirewall = true;
    };

    jellyfin = {
      enable = !jellyfinSettings.vmServiceReady;
      openFirewall = false;
    };

    ombi = {
      enable = false;

      port = consts.ports.host.ombi;
      openFirewall = true;
      dataDir = "/rpool/unenc/apps/nixos/ombi";

      reverseProxy = {
        enable = true;
        domain = "ombi.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };

    tautulli = {
      enable = false;

      port = consts.ports.host.tautulli;
      openFirewall = true;
      dataDir = "/rpool/unenc/apps/nixos/tautulli";

      reverseProxy = {
        enable = true;
        domain = "tautulli.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };
  };

  # The web patch replaces jellyfin-web's install phase. Enable it only after
  # validating it against the running Jellyfin version.
  sys.programs.jellyfinWebSkipIntro.enable = false;

  assertions = [
    {
      assertion = config.networking.firewall.backend == "iptables";
      message = "Blizzard Jellyfin's VPS source guard requires the iptables firewall backend";
    }
    {
      assertion =
        !(builtins.elem 8096 config.networking.firewall.allowedTCPPorts)
        && !(lib.any (
          range: range.from <= 8096 && 8096 <= range.to
        ) config.networking.firewall.allowedTCPPortRanges);
      message = "Blizzard Jellyfin port 8096 must not be open on all host interfaces";
    }
  ]
  ++ lib.optionals jellyfinIngressReady [
    {
      assertion =
        config.sys.services.tailscale.enable
        && config.networking.firewall.enable
        && config.sys.virtualisation.microvm.instances.jellyfin.enable;
      message = "Blizzard Jellyfin VM ingress requires Tailscale, the host firewall, and the VM";
    }
  ];

  # Tailscale normally accepts packets arriving on tailscale0 before the
  # NixOS input chain. Raw PREROUTING runs first; dst-type LOCAL excludes
  # traffic Blizzard forwards as a subnet router. Keep the guard in place even
  # while VPS ingress is off, so a firewall reload cannot expose a stale listener.
  networking.firewall = {
    interfaces.tailscale0.allowedTCPPorts = lib.optionals jellyfinIngressReady [
      jellyfinReg.port
    ];
    inherit (jellyfinFirewall) extraCommands extraStopCommands;
  };

  # The VPS keeps using Blizzard's Tailscale IPv4 and TCP 8096. A bound TCP
  # relay passes Caddy's HTTP/WebSocket stream to the guest without creating
  # an all-interface NAT port-forward. It starts only after private setup.
  systemd.sockets.jellyfin-vps-relay = lib.mkIf jellyfinIngressReady {
    description = "Jellyfin VPS ingress on Blizzard's Tailscale interface";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${consts.tailscale.hosts.blizzard.ipv4}:${toString jellyfinReg.port}" ];
    socketConfig = {
      BindToDevice = "tailscale0";
      FreeBind = true;
    };
  };

  systemd.services.jellyfin-vps-relay = lib.mkIf jellyfinIngressReady {
    description = "Relay Jellyfin VPS traffic to jellyfin-vm";
    after = [ "microvm@jellyfin-vm.service" ];
    requires = [ "microvm@jellyfin-vm.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${jellyfinReg.ip}:${toString jellyfinReg.port}";
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };
}
