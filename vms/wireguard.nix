{
  lib,
  pkgs,
  consts,
  ...
}:
let
  registry = import ./vm-registry.nix;
  reg = registry.wireguard;
  qbtIp = registry.qbittorrent.ip;
  wireguardInterface = "wg0";
  wireguardFwmark = 51820;
  iptablesPath = "${pkgs.iptables}/bin/iptables";
  iptablesRestorePath = "${pkgs.iptables}/bin/iptables-restore";
  homeNetworks = [
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
  ];
  homeNetworkFirewallRules = lib.concatMapStringsSep "\n" (
    network: "-A WG_OUTPUT -d ${network} -j ACCEPT"
  ) homeNetworks;
  legacyFirewallCleanup = lib.concatMapStringsSep "\n" (rule: "${iptablesPath} ${rule} || true") (
    [
      "-D FORWARD -i ens3 -o ${wireguardInterface} -j ACCEPT"
      "-D FORWARD -i ${wireguardInterface} -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT"
      "-D FORWARD -i ens3 ! -o ${wireguardInterface} -j REJECT"
      "-D OUTPUT ! -o ${wireguardInterface} -m mark ! --mark ${toString wireguardFwmark} -m addrtype ! --dst-type LOCAL -j REJECT"
      "-t nat -D PREROUTING -i ${wireguardInterface} -p tcp --dport ${toString consts.qbittorrentTorrentPort} -j DNAT --to-destination ${qbtIp}:${toString consts.qbittorrentTorrentPort}"
      "-t nat -D PREROUTING -i ${wireguardInterface} -p udp --dport ${toString consts.qbittorrentTorrentPort} -j DNAT --to-destination ${qbtIp}:${toString consts.qbittorrentTorrentPort}"
      "-D FORWARD -i ${wireguardInterface} -o ens3 -p tcp --dport ${toString consts.qbittorrentTorrentPort} -j ACCEPT"
      "-D FORWARD -i ${wireguardInterface} -o ens3 -p udp --dport ${toString consts.qbittorrentTorrentPort} -j ACCEPT"
    ]
    ++ map (network: "-D OUTPUT -d ${network} -j ACCEPT") homeNetworks
  );
  wireguardFirewallSetup = ''
    # Keep the tunnel kill switch in private chains that survive a NixOS
    # firewall reload. The chain bodies are replaced as one iptables-restore
    # transaction, so a reload never exposes an empty fail-open policy.
    ${iptablesPath} -N WG_FORWARD 2>/dev/null || true
    ${iptablesPath} -N WG_OUTPUT 2>/dev/null || true
    ${iptablesPath} -t nat -N WG_PREROUTING 2>/dev/null || true

    ${iptablesRestorePath} --noflush <<'EOF'
    *filter
    :WG_FORWARD - [0:0]
    :WG_OUTPUT - [0:0]
    -F WG_FORWARD
    -F WG_OUTPUT
    -A WG_FORWARD -i ens3 -o ${wireguardInterface} -j ACCEPT
    -A WG_FORWARD -i ${wireguardInterface} -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT
    -A WG_FORWARD -i ens3 ! -o ${wireguardInterface} -j REJECT
    -A WG_FORWARD -i ${wireguardInterface} -o ens3 -p tcp --dport ${toString consts.qbittorrentTorrentPort} -j ACCEPT
    -A WG_FORWARD -i ${wireguardInterface} -o ens3 -p udp --dport ${toString consts.qbittorrentTorrentPort} -j ACCEPT
    -A WG_FORWARD -j RETURN
    ${homeNetworkFirewallRules}
    -A WG_OUTPUT ! -o ${wireguardInterface} -m mark ! --mark ${toString wireguardFwmark} -m addrtype ! --dst-type LOCAL -j REJECT
    -A WG_OUTPUT -j RETURN
    COMMIT
    EOF

    ${iptablesRestorePath} --noflush <<'EOF'
    *nat
    :WG_PREROUTING - [0:0]
    -F WG_PREROUTING
    -A WG_PREROUTING -i ${wireguardInterface} -p tcp --dport ${toString consts.qbittorrentTorrentPort} -j DNAT --to-destination ${qbtIp}:${toString consts.qbittorrentTorrentPort}
    -A WG_PREROUTING -i ${wireguardInterface} -p udp --dport ${toString consts.qbittorrentTorrentPort} -j DNAT --to-destination ${qbtIp}:${toString consts.qbittorrentTorrentPort}
    -A WG_PREROUTING -j RETURN
    COMMIT
    EOF

    ${iptablesPath} -C FORWARD -j WG_FORWARD 2>/dev/null || ${iptablesPath} -I FORWARD 1 -j WG_FORWARD
    ${iptablesPath} -C OUTPUT -j WG_OUTPUT 2>/dev/null || ${iptablesPath} -I OUTPUT 1 -j WG_OUTPUT
    ${iptablesPath} -t nat -C PREROUTING -j WG_PREROUTING 2>/dev/null || ${iptablesPath} -t nat -I PREROUTING 1 -j WG_PREROUTING

    # Remove direct rules written by older generations after the replacement
    # chains are active. They are deliberately not removed during firewall
    # stop/reload, which keeps the current kill switch in place.
    ${legacyFirewallCleanup}
  '';
  addHomeNetworkRoutes = lib.concatMapStringsSep "\n" (
    network: "${pkgs.iproute2}/bin/ip route add ${network} via \"$DROUTE\" || true"
  ) homeNetworks;
  removeHomeNetworkRoutes = lib.concatMapStringsSep "\n" (
    network: "${pkgs.iproute2}/bin/ip route del ${network} via \"$DROUTE\" || true"
  ) homeNetworks;
in
{
  imports = [
    ./base.nix
    ../modules/services/wireguard.nix
    (import ./mkMicrovmConfig.nix reg)
  ];

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  # Note: WireGuard private key is stored in /persist/wireguard/privatekey
  # This avoids sops-nix timing issues with SSH keys on MicroVM volumes

  boot = {
    kernelModules = [ "nf_conntrack" ];
    kernel.sysctl = {
      "net.netfilter.nf_conntrack_max" = 32768;
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
    };
  };

  networking = {
    enableIPv6 = false;
    nat = {
      enable = true;
      externalInterface = wireguardInterface;
      internalInterfaces = [ "ens3" ];
    };

    firewall = {
      allowPing = true;
      trustedInterfaces = [ "ens3" ];
      allowedUDPPorts = [ reg.port ];
      extraCommands = wireguardFirewallSetup;
      extraStopCommands = "";
    };
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "ens3";
      bind-interfaces = true;
      listen-address = reg.ip;
      server = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      no-resolv = true;
      cache-size = 1000;
    };
  };

  systemd.tmpfiles.rules = [
    "d /persist/wireguard 0700 root root -"
  ];

  # The firewall must load successfully before the tunnel starts and must stop
  # after it, so forwarded and local traffic stay fail-closed during teardown.
  systemd.services."wg-quick-${wireguardInterface}" = {
    requires = [ "firewall.service" ];
    after = [ "firewall.service" ];
  };

  sys.services.wireguard = {
    enable = true;
    interface = wireguardInterface;
    fwmark = wireguardFwmark;
    openFirewall = true;
    privateKeyFile = "/persist/wireguard/privatekey";
    listenPort = reg.port;
    mtu = 1390;
    dns = [ "1.1.1.1" ];
    addresses = [ "10.13.128.81/24" ];
    postUp = ''
      set -eu
      DROUTE=$(${pkgs.iproute2}/bin/ip route | ${pkgs.gnugrep}/bin/grep default | ${pkgs.gawk}/bin/awk '{print $3}')
      ${addHomeNetworkRoutes}
    '';
    preDown = ''
      set -u
      DROUTE=$(${pkgs.iproute2}/bin/ip route | ${pkgs.gnugrep}/bin/grep default | ${pkgs.gawk}/bin/awk '{print $3}')
      ${removeHomeNetworkRoutes}
    '';
    peers = [
      {
        # none of these are private/sensitive
        publicKey = "8BJ51HLKISBwg5eWBeXOgAX3BUsoXc9hSpBjVnRUuWE=";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "37.120.238.130:1443";
        persistentKeepalive = 25;
      }
    ];
  };
}
