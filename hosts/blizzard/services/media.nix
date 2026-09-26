{
  VARS,
  config,
  consts,
  lib,
  ...
}:
let
  # Set to null to stop Jellyfin while keeping its tailnet ingress closed.
  jellyfinVpsIPv4 = "100.116.146.113";
  jellyfinReady = jellyfinVpsIPv4 != null;
in
{
  sys.services = {
    plex = {
      enable = true;
      openFirewall = true;
    };

    jellyfin = {
      enable = jellyfinReady;
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
  ++ lib.optionals jellyfinReady [
    {
      assertion = config.sys.services.tailscale.enable && config.networking.firewall.enable;
      message = "Blizzard Jellyfin requires Tailscale and the host firewall for VPS ingress";
    }
  ];

  # Tailscale normally accepts packets arriving on tailscale0 before the
  # NixOS input chain. Raw PREROUTING runs first; dst-type LOCAL excludes
  # traffic Blizzard forwards as a subnet router. Keep the guard in place even
  # while Jellyfin is off, so a firewall reload cannot expose a stale listener.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals jellyfinReady [ 8096 ];
  networking.firewall.extraCommands = ''
    iptables -w -t raw -N JELLYFIN_VPS 2>/dev/null || true
    iptables -w -t raw -I JELLYFIN_VPS 1 -j DROP
    ${lib.optionalString jellyfinReady ''
      iptables -w -t raw -I JELLYFIN_VPS 1 -s ${jellyfinVpsIPv4}/32 -j RETURN
    ''}
    while iptables -w -t raw -D JELLYFIN_VPS ${
      if jellyfinReady then "3" else "2"
    } 2>/dev/null; do :; done
    if ! iptables -w -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j JELLYFIN_VPS 2>/dev/null; then
      iptables -w -t raw -I PREROUTING 1 -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j JELLYFIN_VPS
    fi
    if ! ip6tables -w -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j DROP 2>/dev/null; then
      ip6tables -w -t raw -I PREROUTING 1 -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j DROP
    fi
  '';
  networking.firewall.extraStopCommands = ''
    # A firewall restart must fail closed until the new rules are installed.
    iptables -w -t raw -I JELLYFIN_VPS 1 -j DROP 2>/dev/null || true
  '';
}
