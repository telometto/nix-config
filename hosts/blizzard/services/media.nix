{
  VARS,
  config,
  consts,
  lib,
  ...
}:
let
  # Keep ingress closed until the administrator wizard is finished privately.
  # Set this to the dedicated Jellyfin VPS Tailscale IPv4 when ready to publish.
  jellyfinVpsIPv4 = null;
  jellyfinIngressReady = jellyfinVpsIPv4 != null;
  jellyfinFirewall = import ../../../lib/jellyfin-vps-firewall.nix {
    inherit lib;
    vpsIPv4 = jellyfinVpsIPv4;
  };
in
{
  sys.services = {
    plex = {
      enable = true;
      openFirewall = true;
    };

    jellyfin = {
      enable = true;
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
      assertion = config.sys.services.tailscale.enable && config.networking.firewall.enable;
      message = "Blizzard Jellyfin requires Tailscale and the host firewall for VPS ingress";
    }
  ];

  # Tailscale normally accepts packets arriving on tailscale0 before the
  # NixOS input chain. Raw PREROUTING runs first; dst-type LOCAL excludes
  # traffic Blizzard forwards as a subnet router. Keep the guard in place even
  # while VPS ingress is off, so a firewall reload cannot expose a stale listener.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals jellyfinIngressReady [
    8096
  ];
  networking.firewall.extraCommands = jellyfinFirewall.extraCommands;
  networking.firewall.extraStopCommands = jellyfinFirewall.extraStopCommands;
}
