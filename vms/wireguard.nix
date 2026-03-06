{ pkgs, ... }:
let
  reg = (import ./vm-registry.nix).wireguard;
  qbtIp = (import ./vm-registry.nix).qbittorrent.ip;
in
{
  imports = [
    ./base.nix
    ../modules/services/wireguard.nix
    (import ./mkMicrovmConfig.nix reg)
  ];

  # Note: WireGuard private key is stored in /persist/wireguard/privatekey
  # This avoids sops-nix timing issues with SSH keys on MicroVM volumes

  networking = {
    nat = {
      enable = true;
      externalInterface = "wg0";
      internalInterfaces = [ "ens3" ];
    };

    firewall = {
      allowPing = true;
      trustedInterfaces = [ "ens3" ];
      allowedUDPPorts = [ reg.port ];
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 ! -o wg0 -j REJECT

        # Port forward incoming VPN traffic to qBittorrent VM
        ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820
        ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i wg0 -p udp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o ens3 -p tcp --dport 50820 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o ens3 -p udp --dport 50820 -j ACCEPT
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 -o wg0 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 ! -o wg0 -j REJECT || true

        ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i wg0 -p tcp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820 || true
        ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i wg0 -p udp --dport 50820 -j DNAT --to-destination ${qbtIp}:50820 || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o ens3 -p tcp --dport 50820 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o ens3 -p udp --dport 50820 -j ACCEPT || true
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

  sys.services.wireguard = {
    enable = true;
    openFirewall = true;
    privateKeyFile = "/persist/wireguard/privatekey";
    listenPort = reg.port;
    mtu = 1390;
    dns = [ "1.1.1.1" ];
    addresses = [ "10.13.128.81/24" ];
    postUp = ''
      DROUTE=$(${pkgs.iproute2}/bin/ip route | ${pkgs.gnugrep}/bin/grep default | ${pkgs.gawk}/bin/awk '{print $3}')
      HOMENET=192.168.0.0/16
      HOMENET2=10.0.0.0/8
      HOMENET3=172.16.0.0/12
      ${pkgs.iproute2}/bin/ip route add $HOMENET3 via $DROUTE || true
      ${pkgs.iproute2}/bin/ip route add $HOMENET2 via $DROUTE || true
      ${pkgs.iproute2}/bin/ip route add $HOMENET via $DROUTE || true
      ${pkgs.iptables}/bin/iptables -I OUTPUT -d $HOMENET -j ACCEPT
      ${pkgs.iptables}/bin/iptables -A OUTPUT -d $HOMENET2 -j ACCEPT
      ${pkgs.iptables}/bin/iptables -A OUTPUT -d $HOMENET3 -j ACCEPT
      FWMARK=$(${pkgs.wireguard-tools}/bin/wg show %i fwmark)
      if [ -n "$FWMARK" ] && [ "$FWMARK" != "off" ]; then
        ${pkgs.iptables}/bin/iptables -A OUTPUT ! -o %i -m mark ! --mark $FWMARK -m addrtype ! --dst-type LOCAL -j REJECT
      fi
    '';
    preDown = ''
      DROUTE=$(${pkgs.iproute2}/bin/ip route | ${pkgs.gnugrep}/bin/grep default | ${pkgs.gawk}/bin/awk '{print $3}')
      HOMENET=192.168.0.0/16
      HOMENET2=10.0.0.0/8
      HOMENET3=172.16.0.0/12
      ${pkgs.iproute2}/bin/ip route del $HOMENET3 via $DROUTE || true
      ${pkgs.iproute2}/bin/ip route del $HOMENET2 via $DROUTE || true
      ${pkgs.iproute2}/bin/ip route del $HOMENET via $DROUTE || true
      FWMARK=$(${pkgs.wireguard-tools}/bin/wg show %i fwmark 2>/dev/null || echo "")
      if [ -n "$FWMARK" ] && [ "$FWMARK" != "off" ]; then
        ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o %i -m mark ! --mark $FWMARK -m addrtype ! --dst-type LOCAL -j REJECT || true
      fi
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d $HOMENET -j ACCEPT || true
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d $HOMENET2 -j ACCEPT || true
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d $HOMENET3 -j ACCEPT || true
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
