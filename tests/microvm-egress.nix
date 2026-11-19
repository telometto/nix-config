# Public-input packet tests for the shared policy compiler; no private flake.
{
  pkgs,
  policyCompiler ? ../lib/microvm-network-policy.nix,
}:
let
  inherit (pkgs) lib;
  identities = map (identity: identity // { bridge = "microvm-br0"; }) [
    {
      name = "app";
      tap = "vm-app";
      mac = "02:00:00:00:00:02";
      ip = "10.100.0.2";
    }
    {
      name = "wireguard";
      tap = "vm-wireguard";
      mac = "02:00:00:00:00:03";
      ip = "10.100.0.3";
    }
    {
      name = "client";
      tap = "vm-client";
      mac = "02:00:00:00:00:04";
      ip = "10.100.0.4";
    }
  ];
  app = builtins.elemAt identities 0;
  gateway = builtins.elemAt identities 1;
  client = builtins.elemAt identities 2;
  compiler = import policyCompiler;
  policy = compiler (
    builtins.intersectAttrs (builtins.functionArgs compiler) {
      inherit lib identities;
      serviceEdges = [
        {
          source = gateway;
          destination = client;
          tcpPorts = [ 50820 ];
          udpPorts = [ 50820 ];
          reason = "Inbound torrent port";
        }
      ];
      gatewayPairs = [ { inherit client gateway; } ];
      internalBridgeNames = [ "microvm-br0" ];
      mode = "enforce";
      hostServiceRules = [
        {
          source = app;
          tcpPorts = [ 3003 ];
          udpPorts = [ ];
          reason = "Synthetic Immich caller";
        }
      ];
    }
  );
  ruleset = pkgs.writeText "microvm-egress.nft" policy.ruleset;
  wireguardModule = import ../vms/wireguard.nix {
    inherit lib pkgs;
    consts = import ../lib/constants.nix;
  };
  wireguardFirewall = pkgs.writeShellScript "wireguard-output-fixture" wireguardModule.networking.firewall.extraCommands;
  checkSecret = pkgs.writeText "check-runtime-secret.py" ''
    import os
    from pathlib import Path
    assert os.environ["APP_SECRET"] == Path("/etc/fixture-key").read_text().removesuffix("\n")
  '';
  mlFirewall = import ../lib/immich-ml-firewall.nix {
    blizzardIPv4 = "100.100.0.2";
    port = 3003;
  };
  mlStart = pkgs.writeShellScript "start-ml-guard-fixture" ("set -e\n" + mlFirewall.extraCommands);
  mlStop = pkgs.writeShellScript "stop-ml-guard-fixture" ("set -e\n" + mlFirewall.extraStopCommands);
  setup = pkgs.writeShellScript "setup-policy-namespace" ''
    set -eu
    name="$1"; tap="$2"; mac="$3"; address="$4"; gateway="$5"
    ip netns add "$name"
    ip link add "$tap" type veth peer name eth0 netns "$name"
    ip link set "$tap" master microvm-br0
    ip link set "$tap" up
    ip -n "$name" link set lo up
    ip -n "$name" link set eth0 address "$mac"
    ip -n "$name" address add "$address/24" dev eth0
    ip -n "$name" link set eth0 up
    ip -n "$name" route add default via "$gateway"
  '';
in
pkgs.testers.runNixOSTest {
  name = "microvm-egress";
  nodes.machine = {
    networking.useDHCP = false;
    networking.firewall.enable = false;
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernelModules = [ "nf_conntrack_bridge" ];
    environment.systemPackages = [
      pkgs.nftables
      pkgs.iproute2
      pkgs.iptables
      pkgs.socat
    ];
    virtualisation.memorySize = 512;
    # Synthetic public test data, never a deployment credential.
    environment.etc."fixture-key".text = ''
      fixture "quoted" \\ key $HOME $(touch pwned) `touch pwned`
    '';
  };
  testScript = ''
    machine.start()
    machine.succeed("ip link add microvm-br0 type bridge; ip address add 10.100.0.1/24 dev microvm-br0; ip link set microvm-br0 up")
    machine.succeed("${setup} app ${app.tap} ${app.mac} ${app.ip} 10.100.0.1")
    machine.succeed("${setup} gateway ${gateway.tap} ${gateway.mac} ${gateway.ip} 10.100.0.1")
    machine.succeed("${setup} client ${client.tap} ${client.mac} ${client.ip} ${gateway.ip}")
    machine.succeed("ip netns exec gateway sysctl -w net.ipv4.ip_forward=1")
    machine.succeed("ip netns exec gateway iptables -t nat -A POSTROUTING -s ${client.ip}/32 -j MASQUERADE")
    machine.succeed("ip netns add internet; ip link add uplink type veth peer name eth0 netns internet; ip address add 192.0.2.1/24 dev uplink; ip link set uplink up")
    machine.succeed("ip -n internet link set lo up; ip -n internet link set eth0 up; ip -n internet address add 192.0.2.2/24 dev eth0; ip -n internet address add 192.0.2.3/24 dev eth0; ip -n internet route add 10.100.0.0/24 via 192.0.2.1")
    machine.succeed("nft -f ${ruleset}")

    with subtest("ordinary Internet and stateful VPN returns work"):
        machine.succeed("ip netns exec app ping -c 1 -W 2 192.0.2.2")
        machine.succeed("ip netns exec client ping -c 1 -W 2 ${gateway.ip}")
        machine.succeed("ip netns exec client ping -c 1 -W 2 192.0.2.2")

    with subtest("protected destinations are denied even behind the gateway"):
        for address in ["192.168.2.2", "169.254.1.2", "100.64.0.2"]:
            machine.succeed(f"ip -n internet address add {address}/32 dev eth0; ip route add {address}/32 dev uplink")
            machine.fail(f"ip netns exec app ping -c 1 -W 1 {address}")
            machine.fail(f"ip netns exec gateway ping -c 1 -W 1 {address}")
        machine.succeed("nft list counter inet microvm_policy protected_egress_drops | grep -Eq 'packets [1-9]'")

    with subtest("VPN client cannot use the host as a replacement router"):
        machine.succeed("ip -n client route add 192.0.2.3/32 via 10.100.0.1")
        machine.fail("ip netns exec client ping -c 1 -W 1 192.0.2.3")

    machine.succeed("systemd-run --unit app-listener --property=NetworkNamespacePath=/run/netns/app ${pkgs.socat}/bin/socat TCP-LISTEN:8080,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit torrent-tcp --property=NetworkNamespacePath=/run/netns/client ${pkgs.socat}/bin/socat TCP-LISTEN:50820,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit torrent-udp --property=NetworkNamespacePath=/run/netns/client ${pkgs.socat}/bin/socat UDP-RECVFROM:50820,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit blocked-listener --property=NetworkNamespacePath=/run/netns/client ${pkgs.socat}/bin/socat TCP-LISTEN:50821,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    for unit in ["app-listener", "torrent-tcp", "torrent-udp", "blocked-listener"]:
        machine.wait_for_unit(f"{unit}.service")
    with subtest("gateway initiation is restricted to the exact torrent service"):
        machine.fail("ip netns exec gateway ping -c 1 -W 1 ${client.ip}")
        machine.succeed("echo allowed | ip netns exec gateway socat - TCP:${client.ip}:50820,connect-timeout=2 | grep -q allowed")
        machine.succeed("echo allowed | ip netns exec gateway socat -T 2 - UDP:${client.ip}:50820 | grep -q allowed")
        machine.fail("echo denied | ip netns exec gateway socat - TCP:${client.ip}:50821,connect-timeout=1 | grep -q denied")

    with subtest("LAN replies to an inbound connection remain functional"):
        machine.succeed("echo reply | ip netns exec internet socat - TCP:${app.ip}:8080,bind=192.168.2.2,connect-timeout=2 | grep -q reply")

    with subtest("guest host-management access is denied while the declared relay works"):
        machine.succeed("ip address add 192.168.2.1/32 dev uplink")
        for port in [22, 445, 3003]:
            machine.succeed(f"systemd-run --unit host-listener-{port} ${pkgs.socat}/bin/socat TCP-LISTEN:{port},reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
            machine.wait_for_unit(f"host-listener-{port}.service")
        machine.succeed("ip netns exec app ping -c 1 -W 2 10.100.0.1")
        for namespace in ["app", "client", "gateway"]:
            for address in ["10.100.0.1", "192.168.2.1"]:
                for port in [22, 445]:
                    machine.fail(f"echo denied | ip netns exec {namespace} socat - TCP:{address}:{port},connect-timeout=1 | grep -q denied")
        machine.succeed("echo allowed | ip netns exec app socat - TCP:10.100.0.1:3003,connect-timeout=2 | grep -q allowed")
        machine.fail("echo denied | ip netns exec client socat - TCP:10.100.0.1:3003,connect-timeout=1 | grep -q denied")

    with subtest("tailnet subnet routing cannot inherit proxy identity"):
        machine.succeed("ip netns add tailnet; ip link add tailscale0 type veth peer name eth0 netns tailnet; ip address add 100.100.0.1/24 dev tailscale0; ip link set tailscale0 up")
        machine.succeed("ip -n tailnet link set lo up; ip -n tailnet address add 100.100.0.2/24 dev eth0; ip -n tailnet link set eth0 up; ip -n tailnet route add 10.100.0.0/24 via 100.100.0.1")
        machine.fail("echo denied | ip netns exec tailnet socat - TCP:${app.ip}:8080,connect-timeout=1 | grep -q denied")

    with subtest("WireGuard output permits tunnel and LAN replies but no new LAN flow"):
        machine.succeed("ip netns add wg-output; ip link add wg-uplink type veth peer name wg0 netns wg-output; ip link add wg-lan type veth peer name microvm0 netns wg-output")
        machine.succeed("ip address add 198.18.4.1/24 dev wg-uplink; ip link set wg-uplink up; ip address add 192.168.3.1/24 dev wg-lan; ip link set wg-lan up")
        machine.succeed("ip -n wg-output link set lo up; ip -n wg-output link set wg0 up; ip -n wg-output link set microvm0 up; ip -n wg-output address add 198.18.4.2/24 dev wg0; ip -n wg-output address add 192.168.3.2/24 dev microvm0")
        machine.succeed("ip netns exec wg-output ${wireguardFirewall}")
        machine.fail("ip netns exec wg-output ping -c 1 -W 1 192.168.3.1")
        machine.succeed("ip netns exec wg-output ping -c 1 -W 2 198.18.4.1")
        machine.succeed("ping -c 1 -W 2 192.168.3.2")

    with subtest("ML guard precedes Tailscale accepts and stays closed through reload"):
        machine.succeed("ip netns add ml-host; ip netns add ml-peer; ip link add ml-ts type veth peer name eth0 netns ml-peer; ip link set ml-ts netns ml-host; ip -n ml-host link set ml-ts name tailscale0")
        machine.succeed("ip -n ml-host link set lo up; ip -n ml-host link set tailscale0 up; ip -n ml-host address add 100.100.0.1/24 dev tailscale0; ip -n ml-peer link set lo up; ip -n ml-peer link set eth0 up; ip -n ml-peer address add 100.100.0.2/24 dev eth0; ip -n ml-peer address add 100.100.0.3/24 dev eth0")
        machine.succeed("ip -n ml-host -6 address add fd7a:115c:a1e0::1/64 dev tailscale0 nodad; ip -n ml-peer -6 address add fd7a:115c:a1e0::2/64 dev eth0 nodad")
        machine.succeed("ip netns exec ml-host iptables -N nixos-fw; ip netns exec ml-host iptables -N nixos-fw-accept; ip netns exec ml-host iptables -A nixos-fw-accept -j ACCEPT; ip netns exec ml-host iptables -N ts-input; ip netns exec ml-host iptables -A ts-input -i tailscale0 -j ACCEPT; ip netns exec ml-host iptables -I INPUT 1 -j ts-input; ip netns exec ml-host iptables -A INPUT -j nixos-fw")
        machine.succeed("ip netns exec ml-host ip6tables -N ts-input; ip netns exec ml-host ip6tables -A ts-input -i tailscale0 -j ACCEPT; ip netns exec ml-host ip6tables -I INPUT 1 -j ts-input")
        machine.succeed("systemd-run --unit ml-listener --property=NetworkNamespacePath=/run/netns/ml-host ${pkgs.socat}/bin/socat TCP4-LISTEN:3003,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
        machine.succeed("systemd-run --unit ml-listener-v6 --property=NetworkNamespacePath=/run/netns/ml-host ${pkgs.socat}/bin/socat TCP6-LISTEN:3003,ipv6only=1,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
        machine.wait_for_unit("ml-listener.service")
        machine.wait_for_unit("ml-listener-v6.service")
        machine.succeed("echo prior | ip netns exec ml-peer socat - TCP:100.100.0.1:3003,bind=100.100.0.3,connect-timeout=2 | grep -q prior")
        machine.succeed("ip netns exec ml-host ${mlStart}")
        machine.succeed("echo allowed | ip netns exec ml-peer socat - TCP:100.100.0.1:3003,bind=100.100.0.2,connect-timeout=2 | grep -q allowed")
        machine.fail("echo denied | ip netns exec ml-peer socat - TCP:100.100.0.1:3003,bind=100.100.0.3,connect-timeout=1 | grep -q denied")
        machine.fail("echo denied | ip netns exec ml-peer socat - TCP6:[fd7a:115c:a1e0::1]:3003,connect-timeout=1 | grep -q denied")
        machine.succeed("ip netns exec ml-host ${mlStop}")
        machine.fail("echo stopped | ip netns exec ml-peer socat - TCP:100.100.0.1:3003,bind=100.100.0.2,connect-timeout=1 | grep -q stopped")
        machine.succeed("ip netns exec ml-host ${mlStart}")
        machine.succeed("echo resumed | ip netns exec ml-peer socat - TCP:100.100.0.1:3003,bind=100.100.0.2,connect-timeout=2 | grep -q resumed")

    with subtest("runtime secret survives both systemd and shell quoting"):
        machine.succeed("install -d -m 0700 /run/secret-fixture")
        machine.succeed("${pkgs.python3}/bin/python3 ${../lib/runtime-secret-environment.py} APP_SECRET /etc/fixture-key /run/secret-fixture/environment")
        machine.succeed("systemd-run --wait --pipe --unit secret-fixture -p EnvironmentFile=/run/secret-fixture/environment ${pkgs.python3}/bin/python3 ${checkSecret}")
  '';
}
