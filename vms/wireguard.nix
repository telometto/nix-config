{ lib, pkgs, ... }:
let
  registry = import ./vm-registry.nix;
  reg = registry.wireguard;
  qbtIp = registry.qbittorrent.ip;
  wireguardInterface = "wg0";
  wireguardFwmark = 51820;
  homeNetworks = [
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
  ];
  addHomeNetworkFirewallRules = lib.concatMapStringsSep "\n" (
    network: "${pkgs.iptables}/bin/iptables -A OUTPUT -d ${network} -j ACCEPT"
  ) homeNetworks;
  removeHomeNetworkFirewallRules = lib.concatMapStringsSep "\n" (
    network: "${pkgs.iptables}/bin/iptables -D OUTPUT -d ${network} -j ACCEPT || true"
  ) homeNetworks;
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

  # Note: WireGuard private key is stored in /persist/wireguard/privatekey
  # This avoids sops-nix timing issues with SSH keys on MicroVM volumes

  boot = {
    kernelModules = [ "nf_conntrack" ];
    kernel.sysctl."net.netfilter.nf_conntrack_max" = 32768;
  };

  networking = {
    nat = {
      enable = true;
      externalInterface = wireguardInterface;
      internalInterfaces = [ "ens3" ];
    };

    firewall = {
      allowPing = true;
      trustedInterfaces = [ "ens3" ];
      allowedUDPPorts = [ reg.port ];
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 -o ${wireguardInterface} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ${wireguardInterface} -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 ! -o ${wireguardInterface} -j REJECT

        # Keep local gateway traffic fail-closed across tunnel restarts and
        # firewall reloads. RFC1918 routes intentionally remain reachable.
        ${addHomeNetworkFirewallRules}
        ${pkgs.iptables}/bin/iptables -A OUTPUT ! -o ${wireguardInterface} -m mark ! --mark ${toString wireguardFwmark} -m addrtype ! --dst-type LOCAL -j REJECT

        # Port forward incoming VPN traffic to qBittorrent VM
        ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i ${wireguardInterface} -p tcp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820
        ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i ${wireguardInterface} -p udp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ${wireguardInterface} -o ens3 -p tcp --dport 50820 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ${wireguardInterface} -o ens3 -p udp --dport 50820 -j ACCEPT
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 -o ${wireguardInterface} -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ${wireguardInterface} -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 ! -o ${wireguardInterface} -j REJECT || true

        ${removeHomeNetworkFirewallRules}
        ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o ${wireguardInterface} -m mark ! --mark ${toString wireguardFwmark} -m addrtype ! --dst-type LOCAL -j REJECT || true

        ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i ${wireguardInterface} -p tcp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820 || true
        ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i ${wireguardInterface} -p udp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820 || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ${wireguardInterface} -o ens3 -p tcp --dport 50820 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ${wireguardInterface} -o ens3 -p udp --dport 50820 -j ACCEPT || true
      '';
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
