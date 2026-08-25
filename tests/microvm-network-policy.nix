{
  lib,
  pkgs,
  blizzard,
  wireguardVm,
}:
let
  consts = import ../lib/constants.nix;
  registry = import ../vms/vm-registry.nix { inherit consts; };
  networkDefaults = import ../vms/microvm-network-defaults.nix;
  wireguardCfg = wireguardVm.config;
  wireguardFirewallCommands = wireguardCfg.networking.firewall.extraCommands;
  wireguardFirewallStopCommands = wireguardCfg.networking.firewall.extraStopCommands;
  wireguardInterface = wireguardCfg.networking.wg-quick.interfaces.wg0;
  wireguardUnit = wireguardCfg.systemd.services.wg-quick-wg0;

  enforced = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.networkPolicy.mode = lib.mkForce "enforce";
      }
    ];
  };
  enforcedCfg = enforced.config;
  policyService = enforcedCfg.systemd.services."microvm-network-policy";
  policyReloadCommands = lib.filter (command: command != "") (
    lib.splitString "\n" policyService.reload
  );
  policyCounterSnapshotCommand = lib.head policyReloadCommands;
  policyCounterSnapshotScript = builtins.readFile policyCounterSnapshotCommand;
  enabledIdentityNames = builtins.attrNames (
    lib.filterAttrs (_: instance: instance.enable) enforcedCfg.sys.virtualisation.microvm.instances
  );
  policyIdentityNames = lib.filter (name: builtins.hasAttr name registry) enabledIdentityNames;
  policyTapNames = map (
    name:
    let
      entry = registry.${name};
    in
    entry.tapId or "vm-${entry.name}"
  ) policyIdentityNames;
  dedicatedIdentityNames = lib.filter (name: registry.${name} ? hostBridge) policyIdentityNames;
  policyNetdevNames = [
    "10-${networkDefaults.sharedBridge.name}"
  ]
  ++ map (name: "10-${name}-bridge") dedicatedIdentityNames;
  policyNetworkNames = [
    "10-${networkDefaults.sharedBridge.name}"
    "12-microvm-tap"
  ]
  ++ map (name: "10-${name}-bridge") dedicatedIdentityNames
  ++ map (name: "11-${name}-tap") policyIdentityNames;
  vpnClientNames = lib.filter (
    name: (registry.${name}.gateway or networkDefaults.defaultGateway) == registry.wireguard.ip
  ) policyIdentityNames;
  policyRuleset = enforcedCfg.environment.etc."microvm-network-policy/ruleset.nft".source;

  audited = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.networkPolicy.mode = lib.mkForce "audit";
      }
    ];
  };

  policyNetdevs = lib.filterAttrs (
    name: _: lib.elem name policyNetdevNames
  ) enforcedCfg.systemd.network.netdevs;
  policyNetworks = lib.filterAttrs (
    name: _: lib.elem name policyNetworkNames
  ) enforcedCfg.systemd.network.networks;

  policyText = enforcedCfg.sys.virtualisation.microvm.networkPolicy.renderedRuleset;
  auditPolicyText = audited.config.sys.virtualisation.microvm.networkPolicy.renderedRuleset;
  fdbInstallers = map (
    name: enforcedCfg.systemd.services."microvm-tap-interfaces@${name}-vm".postStart
  ) policyIdentityNames;

  invalidUnknownTarget = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.unknown = {
          primaryService = true;
          reason = "Negative test";
        };
      }
    ];
  };
  invalidDisabledTarget = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.actual = {
          primaryService = true;
          reason = "Negative test";
        };
      }
    ];
  };
  invalidDisabledSource = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.actual.networkPolicy.allowedPeers.gitea = {
          primaryService = true;
          reason = "Negative test";
        };
      }
    ];
  };
  invalidDedicatedTarget = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.pocket-id = {
          primaryService = true;
          reason = "Negative test";
        };
      }
    ];
  };
  invalidMissingReason = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.gitea.primaryService =
          true;
      }
    ];
  };
  invalidSelfEdge = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.prowlarr = {
          primaryService = true;
          reason = "Negative test";
        };
      }
    ];
  };
  invalidDuplicatePort = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.prowlarr.networkPolicy.allowedPeers.gitea = {
          primaryService = true;
          tcpPorts = [ registry.gitea.port ];
          reason = "Negative test";
        };
      }
    ];
  };

  hasFailedAssertion =
    message: cfg:
    lib.any (assertion: !assertion.assertion && assertion.message == message) cfg.assertions;

  evaluationFails =
    message: configuration:
    let
      evaluation = builtins.tryEval configuration.config.system.build.toplevel.drvPath;
    in
    !evaluation.success && hasFailedAssertion message configuration.config;

  setupNamespace = pkgs.writeShellScript "setup-microvm-policy-namespace" ''
    set -eu

    namespace_name="$1"
    tap_name="$2"
    guest_mac="$3"
    guest_address="$4"
    guest_gateway="$5"

    ip netns add "$namespace_name"
    ip link add "$tap_name" type veth peer name eth0 netns "$namespace_name"
    ip netns exec "$namespace_name" sysctl -w net.ipv6.conf.all.disable_ipv6=1
    ip -n "$namespace_name" link set lo up
    ip -n "$namespace_name" link set eth0 address "$guest_mac"
    ip -n "$namespace_name" address add "$guest_address" dev eth0
    ip -n "$namespace_name" link set eth0 up
    ip -n "$namespace_name" route add default via "$guest_gateway"
    ip link set "$tap_name" up
  '';

  setupGatewayNat = pkgs.writeShellScript "setup-microvm-policy-gateway-nat" ''
    set -eu

    namespace_name="$1"
    client_address="$2"

    ip netns exec "$namespace_name" sysctl -w net.ipv4.ip_forward=1
    ip netns exec "$namespace_name" nft add table ip policy_test_nat
    ip netns exec "$namespace_name" nft 'add chain ip policy_test_nat postrouting { type nat hook postrouting priority srcnat; policy accept; }'
    ip netns exec "$namespace_name" nft add rule ip policy_test_nat postrouting ip saddr "$client_address" masquerade
  '';

  policyNamespaceSetup = lib.concatMapStringsSep "\n" (
    name:
    let
      entry = registry.${name};
      tapName = entry.tapId or "vm-${entry.name}";
      prefixLength = entry.prefixLength or networkDefaults.defaultPrefixLength;
      gateway = entry.gateway or networkDefaults.defaultGateway;
    in
    ''machine.succeed("${setupNamespace} ns-${name} ${tapName} ${entry.mac} ${entry.ip}/${toString prefixLength} ${gateway}")''
  ) policyIdentityNames;
in
assert blizzard.options.sys.virtualisation.microvm.networkPolicy.mode.default == "enforce";
assert blizzard.config.sys.virtualisation.microvm.networkPolicy.mode == "enforce";
assert enforcedCfg.sys.virtualisation.microvm.networkPolicy.mode == "enforce";
assert !blizzard.config.networking.nftables.enable;
assert policyService.reloadTriggers != [ ];
assert policyService.restartTriggers == [ ];
assert
  policyService.serviceConfig.ExecStart
  == "${pkgs.nftables}/bin/nft --file /etc/microvm-network-policy/ruleset.nft";
assert policyService.serviceConfig.StateDirectory == "microvm-network-policy";
assert lib.hasInfix "snapshot-microvm-policy-counters" policyCounterSnapshotCommand;
assert lib.hasInfix "counter-snapshots.nft" policyCounterSnapshotScript;
assert lib.hasInfix "counter name lateral_audit" auditPolicyText;
assert lib.hasInfix ''log prefix "microvm-policy audit: "'' auditPolicyText;
assert lib.hasInfix "counter name lateral_drops" policyText;
assert lib.hasInfix
  ''iifname "${networkDefaults.sharedBridge.name}" oifname "${networkDefaults.sharedBridge.name}" jump deny_routed_lateral''
  policyText;
assert lib.hasInfix ''iifname "vm-prowlarr" oifname "vm-sonarr"'' policyText;
assert lib.hasInfix "tcp dport { ${toString registry.sonarr.port} }" policyText;
assert lib.all
  (
    sourceName:
    lib.hasInfix ''iifname "vm-${sourceName}" oifname "vm-prowlarr" ether daddr ${registry.prowlarr.mac} ip daddr ${registry.prowlarr.ip} tcp dport { ${toString registry.prowlarr.port} }'' policyText
  )
  [
    "sonarr"
    "radarr"
    "readarr"
  ];
assert !lib.hasInfix "tcp dport { 5355 }" policyText;
assert lib.hasInfix ''iifname "vm-qbittorrent" oifname "vm-wireguard"'' policyText;
assert lib.hasInfix ''iifname "vm-*" jump deny_unknown_tap'' policyText;
assert lib.hasInfix "vm-prowlarr microvm-br0 ${registry.prowlarr.mac}"
  enforcedCfg.systemd.services."microvm-tap-interfaces@prowlarr-vm".postStart;
assert lib.hasInfix ''comment "prowlarr->sonarr: Synchronize indexers with Sonarr"'' policyText;
assert !enforcedCfg.systemd.network.networks."11-prowlarr-tap".bridgeConfig.UnicastFlood;
assert !enforcedCfg.systemd.network.networks."11-prowlarr-tap".bridgeConfig.MulticastFlood;
assert lib.elem {
  Address = registry.prowlarr.ip;
  LinkLayerAddress = registry.prowlarr.mac;
} enforcedCfg.systemd.network.networks."10-${networkDefaults.sharedBridge.name}".neighbors;
assert lib.all (
  name:
  lib.elem "microvm-network-policy.service" enforcedCfg.systemd.services."microvm@${name}-vm".requires
) policyIdentityNames;
assert wireguardCfg.boot.kernel.sysctl."net.netfilter.nf_conntrack_max" or null == 32768;
assert wireguardCfg.networking.enableIPv6 == false;
assert wireguardCfg.boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" or null == 1;
assert wireguardCfg.boot.kernel.sysctl."net.ipv6.conf.default.disable_ipv6" or null == 1;
assert wireguardInterface.extraOptions.FwMark or null == 51820;
assert !lib.hasInfix "%i" wireguardInterface.postUp;
assert lib.hasInfix
  "-A WG_OUTPUT ! -o wg0 -m mark ! --mark 51820 -m addrtype ! --dst-type LOCAL -j REJECT"
  wireguardFirewallCommands;
assert lib.hasInfix "iptables-restore --noflush" wireguardFirewallCommands;
# NixOS NAT contributes its own teardown; the custom kill-switch chains must
# remain installed when the firewall is stopped or reloaded.
assert lib.all (chain: !lib.hasInfix chain wireguardFirewallStopCommands) [
  "WG_FORWARD"
  "WG_OUTPUT"
  "WG_PREROUTING"
];
assert lib.elem "firewall.service" wireguardUnit.requires;
assert lib.elem "firewall.service" wireguardUnit.after;
assert lib.all (
  clientName:
  let
    clientUnit = enforcedCfg.systemd.services."microvm@${clientName}-vm";
  in
  lib.elem "microvm@wireguard-vm.service" clientUnit.requires
  && lib.elem "microvm@wireguard-vm.service" clientUnit.after
  && lib.elem "microvm@wireguard-vm.service" clientUnit.wantedBy
  && lib.elem "microvm@wireguard-vm.service" clientUnit.partOf
) vpnClientNames;
assert evaluationFails
  "sys.virtualisation.microvm network policy has unregistered targets: prowlarr->unknown"
  invalidUnknownTarget;
assert evaluationFails
  "sys.virtualisation.microvm network policy declarations cannot target disabled VMs: prowlarr->actual"
  invalidDisabledTarget;
assert evaluationFails
  "sys.virtualisation.microvm network policy declarations cannot have disabled sources: actual->gitea"
  invalidDisabledSource;
assert evaluationFails
  "sys.virtualisation.microvm dedicated-bridge VMs cannot have direct VM peer permissions: prowlarr->pocket-id"
  invalidDedicatedTarget;
assert evaluationFails
  "sys.virtualisation.microvm network policy permissions require a non-empty reason: prowlarr->gitea"
  invalidMissingReason;
assert evaluationFails
  "sys.virtualisation.microvm network policy cannot declare self-edges: prowlarr->prowlarr"
  invalidSelfEdge;
assert evaluationFails
  "sys.virtualisation.microvm network policy permissions contain duplicate ports: prowlarr->gitea"
  invalidDuplicatePort;
pkgs.testers.runNixOSTest {
  name = "microvm-network-policy";

  nodes.machine =
    { pkgs, ... }:
    {
      boot.kernelModules = [ "nf_conntrack_bridge" ];
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

      networking = {
        firewall.enable = false;
        useDHCP = false;
        useNetworkd = true;
      };

      systemd.network = {
        enable = true;
        wait-online.enable = false;
        netdevs = policyNetdevs;
        networks = policyNetworks;
      };

      environment.systemPackages = with pkgs; [
        iproute2
        iputils
        jq
        nftables
        socat
        tcpdump
      ];

      systemd.services.microvm-network-policy = {
        description = "MicroVM network policy under test";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.nftables}/bin/nft --file ${policyRuleset}";
          ExecReload = "${pkgs.nftables}/bin/nft --file ${policyRuleset}";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("systemd-networkd.service")
    machine.wait_for_unit("microvm-network-policy.service")

    with subtest("policy owns atomic bridge and inet tables"):
        machine.succeed("nft list table bridge microvm_policy | grep -q 'chain deny_spoof'")
        machine.succeed("nft list table inet microvm_policy | grep -q 'routed_lateral_drops'")

    ${policyNamespaceSetup}
    machine.succeed("${setupNamespace} ns-rogue vm-rogue 02:00:00:00:00:EE 10.100.0.90/24 10.100.0.1")
    machine.succeed("${setupGatewayNat} ns-wireguard ${registry.qbittorrent.ip}")

    machine.succeed("ip netns add ns-internet")
    machine.succeed("ip link add uplink-test type veth peer name eth0 netns ns-internet")
    machine.succeed("ip address add 192.0.2.1/24 dev uplink-test")
    machine.succeed("ip link set uplink-test up")
    machine.succeed("ip -n ns-internet link set lo up")
    machine.succeed("ip -n ns-internet address add 192.0.2.2/24 dev eth0")
    machine.succeed("ip -n ns-internet link set eth0 up")
    machine.succeed("ip -n ns-internet route add 10.100.0.0/24 via 192.0.2.1")

    for tap_name in ${builtins.toJSON policyTapNames} + ["vm-rogue"]:
        machine.wait_until_succeeds(f"bridge link show dev {tap_name} | grep -q 'master .*br0'")
    machine.wait_until_succeeds("ip -4 address show dev microvm-br0 | grep -q '10.100.0.1/24'")
    machine.wait_until_succeeds("ip -4 address show dev pocket-id-br0 | grep -q '10.100.1.1/30'")
    for fdb_installer in ${builtins.toJSON fdbInstallers}:
        machine.succeed(fdb_installer)

    with subtest("policy reload keeps dependent taps alive"):
        machine.succeed("systemctl reload microvm-network-policy.service")
        machine.wait_for_unit("microvm-network-policy.service")
        for tap_name in ${builtins.toJSON policyTapNames}:
            machine.succeed(f"bridge link show dev {tap_name} | grep -q 'master .*br0'")

    with subtest("host lifecycle installs static identity and anti-flood state"):
        machine.succeed("ip neigh show ${registry.prowlarr.ip} dev microvm-br0 | grep -qi '${registry.prowlarr.mac}.*PERMANENT'")
        machine.succeed("bridge fdb show dev vm-prowlarr | grep -qi '${registry.prowlarr.mac}.*master.*static'")
        machine.succeed("bridge -details link show dev vm-prowlarr | grep -Eq 'learning on.*flood off'")
        machine.succeed("bridge -details link show dev vm-rogue | grep -q 'flood off'")

    with subtest("registered guest and host traffic remains functional"):
        machine.succeed("ip netns exec ns-prowlarr ping -c 1 -W 2 10.100.0.1")
        machine.succeed("ping -c 1 -W 2 ${registry.prowlarr.ip}")
        machine.succeed("ip netns exec ns-prowlarr ping -c 1 -W 2 192.0.2.2")

    machine.succeed("systemd-run --unit policy-sonarr-listener --property=NetworkNamespacePath=/run/netns/ns-sonarr ${pkgs.socat}/bin/socat TCP-LISTEN:${toString registry.sonarr.port},reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit policy-prowlarr-listener --property=NetworkNamespacePath=/run/netns/ns-prowlarr ${pkgs.socat}/bin/socat TCP-LISTEN:${toString registry.prowlarr.port},reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit policy-prowlarr-llmnr-listener --property=NetworkNamespacePath=/run/netns/ns-prowlarr ${pkgs.socat}/bin/socat TCP-LISTEN:5355,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.succeed("systemd-run --unit policy-gitea-listener --property=NetworkNamespacePath=/run/netns/ns-gitea ${pkgs.socat}/bin/socat TCP-LISTEN:${toString registry.gitea.port},reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
    machine.wait_for_unit("policy-sonarr-listener.service")
    machine.wait_for_unit("policy-prowlarr-listener.service")
    machine.wait_for_unit("policy-prowlarr-llmnr-listener.service")
    machine.wait_for_unit("policy-gitea-listener.service")

    with subtest("declared service is directional and port scoped"):
        machine.succeed("echo allowed | ip netns exec ns-prowlarr ${pkgs.socat}/bin/socat - TCP:${registry.sonarr.ip}:${toString registry.sonarr.port},connect-timeout=2 | grep -q allowed")
        machine.fail("ip netns exec ns-prowlarr ping -c 1 -W 1 ${registry.sonarr.ip}")
        machine.fail("echo denied | ip netns exec ns-prowlarr ${pkgs.socat}/bin/socat - TCP:${registry.gitea.ip}:${toString registry.gitea.port},connect-timeout=1")

    with subtest("audited Arr clients can query Prowlarr without permitting LLMNR"):
        for source_namespace in ["ns-sonarr", "ns-radarr", "ns-readarr"]:
            machine.succeed(f"echo allowed | ip netns exec {source_namespace} ${pkgs.socat}/bin/socat - TCP:${registry.prowlarr.ip}:${toString registry.prowlarr.port},connect-timeout=2 | grep -q allowed")
            machine.fail(f"echo denied | ip netns exec {source_namespace} ${pkgs.socat}/bin/socat - TCP:${registry.prowlarr.ip}:5355,connect-timeout=1")

    with subtest("registered WireGuard pair remains bidirectional"):
        machine.succeed("ip netns exec ns-qbittorrent ping -c 1 -W 2 ${registry.wireguard.ip}")
        machine.succeed("ip netns exec ns-wireguard ping -c 1 -W 2 ${registry.qbittorrent.ip}")
        machine.succeed("ip netns exec ns-qbittorrent ping -c 1 -W 2 192.0.2.2")

    with subtest("VPN client cannot use its gateway to bypass lateral policy"):
        machine.succeed("ip -n ns-qbittorrent route replace ${registry.gitea.ip}/32 via ${registry.wireguard.ip}")
        machine.fail("ip netns exec ns-qbittorrent ping -c 1 -W 1 ${registry.gitea.ip}")
        machine.succeed("nft list counter bridge microvm_policy gateway_bypass_drops | grep -Eq 'packets [1-9]'")

    with subtest("same-bridge host routing and dedicated bridge routing are denied"):
        machine.succeed("ip -n ns-prowlarr route replace ${registry.gitea.ip}/32 via 10.100.0.1")
        machine.fail("ip netns exec ns-prowlarr ping -c 1 -W 1 ${registry.gitea.ip}")
        machine.succeed("ip netns exec ns-pocket-id ping -c 1 -W 2 ${registry.pocket-id.gateway}")
        machine.fail("ip netns exec ns-pocket-id ping -c 1 -W 1 ${registry.prowlarr.ip}")
        machine.fail("ip netns exec ns-prowlarr ping -c 1 -W 1 ${registry.pocket-id.ip}")
        machine.succeed("nft list counter inet microvm_policy routed_lateral_drops | grep -Eq 'packets [1-9]'")

    with subtest("forged MAC IP and ARP identities are rejected"):
        machine.succeed("ip netns exec ns-gitea ping -c 1 -W 2 10.100.0.1")
        machine.succeed("ip -n ns-prowlarr link set eth0 down")
        machine.succeed("ip -n ns-prowlarr link set eth0 address ${registry.gitea.mac}")
        machine.succeed("ip -n ns-prowlarr link set eth0 up")
        machine.fail("ip netns exec ns-prowlarr ping -c 1 -W 1 10.100.0.1")
        machine.succeed("ip -n ns-prowlarr link set eth0 down")
        machine.succeed("ip -n ns-prowlarr link set eth0 address ${registry.prowlarr.mac}")
        machine.succeed("ip -n ns-prowlarr link set eth0 up")
        machine.succeed("ip -n ns-prowlarr address add 10.100.0.99/32 dev eth0")
        machine.fail("ip netns exec ns-prowlarr ping -I 10.100.0.99 -c 1 -W 1 10.100.0.1")
        machine.succeed("ip -n ns-prowlarr address add 10.100.0.1/32 dev eth0")
        machine.fail("ip netns exec ns-prowlarr arping -c 1 -w 1 -I eth0 -s 10.100.0.1 ${registry.gitea.ip}")
        machine.succeed("nft list counter bridge microvm_policy spoof_drops | grep -Eq 'packets [1-9]'")
        machine.succeed("bridge fdb show dev vm-gitea | grep -qi '${registry.gitea.mac}.*master.*static'")
        machine.fail("bridge fdb show dev vm-prowlarr | grep -qi '${registry.gitea.mac}.*master'")
        machine.succeed("ip neigh show ${registry.prowlarr.ip} dev microvm-br0 | grep -qi '${registry.prowlarr.mac}.*PERMANENT'")
        machine.succeed("host_mac=$(cat /sys/class/net/microvm-br0/address); ip netns exec ns-gitea ip neigh show 10.100.0.1 | grep -qi \"$host_mac\"")

    with subtest("IPv6 and unsupported EtherTypes are rejected"):
        machine.succeed("ip -6 address add 2001:db8:100::1/64 dev microvm-br0")
        machine.succeed("ip netns exec ns-gitea sysctl -w net.ipv6.conf.all.disable_ipv6=0")
        machine.succeed("ip -n ns-gitea -6 address add 2001:db8:100::50/64 dev eth0 nodad")
        machine.fail("ip netns exec ns-gitea ping -6 -c 1 -W 1 2001:db8:100::1")
        machine.succeed("nft list counter bridge microvm_policy invalid_drops | grep -Eq 'packets [1-9]'")

    with subtest("unknown tap fails closed in both directions"):
        machine.fail("ip netns exec ns-rogue ping -c 1 -W 1 10.100.0.1")
        machine.fail("ping -c 1 -W 1 10.100.0.90")
        machine.succeed("nft list counter bridge microvm_policy unknown_tap_drops | grep -Eq 'packets [1-9]'")
  '';
}
