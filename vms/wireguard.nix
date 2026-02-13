{
  lib,
  config,
  pkgs,
  inputs,
  VARS,
  ...
}:
{
  imports = [
    ./base.nix
    ../modules/services/wireguard.nix
  ];

  # Note: WireGuard private key is stored in /persist/wireguard/privatekey
  # This avoids sops-nix timing issues with SSH keys on MicroVM volumes

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 116;

    mem = 512;
    vcpu = 1;

    volumes = [
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64;
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-wireguard";
        mac = "02:00:00:00:00:11";
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    hostName = "wireguard-vm";

    useDHCP = false;
    useNetworkd = true;

    nat = {
      enable = true;
      externalInterface = "wg0";
      internalInterfaces = [ "ens3" ];
    };

    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = [ "ens3" ];
      allowedUDPPorts = [ 56943 ];
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ens3 ! -o wg0 -j REJECT
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 -o wg0 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o ens3 -m state --state RELATED,ESTABLISHED -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ens3 ! -o wg0 -j REJECT || true
      '';
    };
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "ens3";
      bind-interfaces = true;
      listen-address = "10.100.0.11";
      server = [ "1.1.1.1" "1.0.0.1" ];
      no-resolv = true;
      cache-size = 1000;
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.11/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /persist/wireguard 0700 root root -"
    ];
  };

  sys.services.wireguard = {
    enable = true;
    openFirewall = true;
    privateKeyFile = "/persist/wireguard/privatekey";
    listenPort = 56943;
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
        publicKey = "8BJ51HLKISBwg5eWBeXOgAX3BUsoXc9hSpBjVnRUuWE=";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "37.120.238.130:1443";
        persistentKeepalive = 25;
      }
    ];
  };

  services.openssh.hostKeys = [
    {
      path = "/persist/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
