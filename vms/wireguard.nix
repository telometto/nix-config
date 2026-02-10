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
      internalInterfaces = [ "eth0" ];
    };

    firewall = {
      enable = true;
      allowedUDPPorts = [ 56943 ];
      extraCommands = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i eth0 ! -o wg0 -j REJECT
      '';
      extraStopCommands = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i eth0 -o wg0 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i eth0 ! -o wg0 -j REJECT || true
      '';
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.26/24" ];
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
    postUp = [
      "DROUTE=$(ip route | grep default | awk '{print $3}'); HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route add $HOMENET3 via $DROUTE; ip route add $HOMENET2 via $DROUTE; ip route add $HOMENET via $DROUTE; iptables -I OUTPUT -d $HOMENET -j ACCEPT; iptables -A OUTPUT -d $HOMENET2 -j ACCEPT; iptables -A OUTPUT -d $HOMENET3 -j ACCEPT; iptables -A OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT"
    ];
    preDown = [
      "DROUTE=$(ip route | grep default | awk '{print $3}'); HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route del $HOMENET3 via $DROUTE; ip route del $HOMENET2 via $DROUTE; ip route del $HOMENET via $DROUTE; iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT; iptables -D OUTPUT -d $HOMENET -j ACCEPT; iptables -D OUTPUT -d $HOMENET2 -j ACCEPT; iptables -D OUTPUT -d $HOMENET3 -j ACCEPT"
    ];
    peers = [
      {
        publicKey = "<REDACTED>";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "<REDACTED>:1443";
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

  system.stateVersion = "24.11";
}
