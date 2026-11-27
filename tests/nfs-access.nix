# Public NFS access checks. Every exported directory exists only in this VM.
{ pkgs }:
let
  inherit (pkgs) lib;
  consts = import ../lib/constants.nix;
  registry = import ../vms/vm-registry.nix { inherit consts; };
  networkDefaults = import ../vms/microvm-network-defaults.nix;
  serverAddress = consts.tailscale.hosts.blizzard.ipv4;
  snowfallAddress = consts.tailscale.hosts.snowfall.ipv4;
  avalancheAddress = consts.tailscale.hosts.avalanche.ipv4;
  fixturePaths = [
    "/srv/nfs-fixture/transfers"
    "/srv/nfs-fixture/media"
    "/srv/nfs-fixture/consume"
  ];
  productionPaths = [
    "/rpool/enc/transfers"
    "/rpool/unenc/media/data/media"
    "/flash/enc/personal/paperless-consumption"
  ];
  paperlessOption = {
    options.sys.virtualisation.microvm.instances = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
  mkHost =
    enabled:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = { inherit consts; };
      modules = [
        ../modules/services/nfs.nix
        ../hosts/blizzard/storage/nfs.nix
        paperlessOption
        {
          system.stateVersion = "25.05";
          services.tailscale.enable = true;
          sys.virtualisation.microvm.instances.paperless.enable = enabled;
        }
      ];
    }).config;
  enabled = mkHost true;
  disabled = mkHost false;
  hostInstances =
    paperlessEnabled:
    import ../hosts/blizzard/virtualisation/microvms.nix {
      inherit lib pkgs consts;
      self = { };
      VARS.domains.public = "fixture.invalid";
      jellyfinSettings.gpuPassthrough.enable = false;
      config.sys = {
        services.nfs.server.enable = true;
        virtualisation.microvm.instances.paperless.enable = paperlessEnabled;
      };
    };
  host = hostInstances true;
  hostOff = hostInstances false;
  paperless = registry.paperless // {
    tap = registry.paperless.tapId or "vm-${registry.paperless.name}";
    bridge = networkDefaults.sharedBridge.name;
  };
  browser = registry.firefox // {
    tap = registry.firefox.tapId or "vm-${registry.firefox.name}";
    bridge = networkDefaults.sharedBridge.name;
  };
  permission = host.sys.virtualisation.microvm.instances.paperless.networkPolicy.hostServices;
  policy = import ../lib/microvm-network-policy.nix {
    inherit lib;
    identities = [
      paperless
      browser
    ];
    serviceEdges = [ ];
    gatewayPairs = [ ];
    internalBridgeNames = [ networkDefaults.sharedBridge.name ];
    mode = "enforce";
    hostServiceRules = [
      {
        source = paperless;
        inherit (permission) tcpPorts reason;
        udpPorts = permission.udpPorts or [ ];
      }
    ];
  };
  ruleset = pkgs.writeText "nfs-microvm-policy.nft" policy.ruleset;
  fixtureExports =
    lib.replaceStrings productionPaths fixturePaths
      enabled.sys.services.nfs.server.exports;
  setupClient = pkgs.writeShellScript "nfs-fixture-client" ''
    set -eu
    name="$1"; bridge="$2"; address="$3"; prefix="$4"; gateway="$5"; mac="$6"
    tap="ns-$name"
    if [ "$bridge" = microvm-br0 ]; then tap="vm-$name"; fi
    ip netns add "$name"
    ip link add "$tap" type veth peer name eth0 netns "$name"
    ip link set "$tap" master "$bridge"
    ip link set "$tap" up
    ip -n "$name" link set lo up
    ip -n "$name" link set eth0 address "$mac"
    ip -n "$name" address add "$address/$prefix" dev eth0
    ip -n "$name" link set eth0 up
    ip -n "$name" route add default via "$gateway"
  '';
in
assert enabled.sys.services.nfs.server.enable;
assert !enabled.sys.services.nfs.server.openFirewall;
assert !(lib.hasInfix registry.paperless.ip disabled.sys.services.nfs.server.exports);
assert lib.hasInfix registry.paperless.ip enabled.sys.services.nfs.server.exports;
assert !(lib.hasInfix registry.firefox.ip enabled.sys.services.nfs.server.exports);
assert !(lib.hasInfix registry.brave.ip enabled.sys.services.nfs.server.exports);
assert !(lib.hasInfix "no_root_squash" enabled.sys.services.nfs.server.exports);
assert !(lib.hasInfix "no_subtree_check" enabled.sys.services.nfs.server.exports);
assert lib.hasInfix ",subtree_check," enabled.sys.services.nfs.server.exports;
assert !(lib.hasInfix "/24" enabled.sys.services.nfs.server.exports);
assert !(lib.hasInfix "*" enabled.sys.services.nfs.server.exports);
assert permission.tcpPorts == [ 2049 ];
assert !(lib.hasInfix "--dport 2049" hostOff.networking.firewall.extraCommands);
assert lib.all
  (
    name:
    lib.elem "nfs-firewall-ready.service" enabled.systemd.services.${name}.requires
    && lib.elem "firewall.service" enabled.systemd.services.${name}.after
  )
  [
    "nfs-server"
    "nfs-mountd"
    "rpc-statd"
    "rpcbind"
  ];
assert lib.elem "nfs-firewall-ready.service" enabled.systemd.sockets.rpcbind.requires;
pkgs.testers.runNixOSTest {
  name = "nfs-access";
  nodes.machine = {
    imports = [
      ../modules/services/nfs.nix
      ../hosts/blizzard/storage/nfs.nix
      paperlessOption
    ];
    _module.args = { inherit consts; };
    services.tailscale.enable = true;
    # No live tailnet or credentials; tailscale0 is a synthetic bridge below.
    sys.virtualisation.microvm.instances.paperless.enable = true;
    sys.services.nfs.server.exports = lib.mkForce fixtureExports;
    networking.useDHCP = false;
    networking.firewall.extraCommands = lib.mkAfter host.networking.firewall.extraCommands;
    boot.kernelModules = [ "nf_conntrack_bridge" ];
    systemd = {
      services.tailscaled.enable = false;
      # Deliberately fail the first firewall start before any raw rules exist.
      services.firewall.preStart = "test -e /run/nfs-fixture-firewall-ready";
      tmpfiles.rules = lib.concatMap (path: [
        "d ${path} 0755 1100 1100 -"
        "f ${path}/seed 0644 1100 1100 - fixture-data"
        "f ${path}/root-only 0600 root root - root-private"
        "d ${path}/root-probe 0777 root root -"
      ]) fixturePaths;
    };
    environment.systemPackages = [
      pkgs.nfs-utils
      pkgs.iproute2
      pkgs.iptables
      pkgs.nftables
      pkgs.socat
      pkgs.netcat-openbsd
      pkgs.util-linux
    ];
    virtualisation.memorySize = 768;
  };
  testScript = ''
    import shlex

    machine.start()
    with subtest("initial firewall failure prevents every NFS listener"):
        machine.wait_until_succeeds("systemctl is-failed nfs-firewall-ready.service")
        machine.fail("systemctl is-active nfs-server.service")
        machine.fail("systemctl is-active nfs-mountd.service")
        machine.fail("systemctl is-active rpc-statd.service")
        machine.fail("systemctl is-active rpcbind.socket")
        machine.fail("ss -ltnu | grep -Eq ':(111|2049|4000|4001|4002)[[:space:]]'")
        machine.succeed("touch /run/nfs-fixture-firewall-ready; systemctl reset-failed; systemctl start firewall.service nfs-server.service")
    machine.wait_for_unit("nfs-server.service")
    machine.wait_for_unit("firewall.service")
    for bridge, address in [("tailscale0", "${serverAddress}/10"), ("microvm-br0", "10.100.0.1/24"), ("fixture-lan", "192.0.2.1/24")]:
        machine.succeed(f"ip link add {bridge} type bridge; ip addr add {address} dev {bridge}; ip link set {bridge} up")
    clients = [
        ("snowfall", "tailscale0", "${snowfallAddress}", 10, "${serverAddress}", "02:00:00:00:01:01"),
        ("avalanche", "tailscale0", "${avalancheAddress}", 10, "${serverAddress}", "02:00:00:00:01:02"),
        ("other", "tailscale0", "100.90.0.1", 10, "${serverAddress}", "02:00:00:00:01:03"),
        ("paperless", "microvm-br0", "${paperless.ip}", 24, "10.100.0.1", "${paperless.mac}"),
        ("firefox", "microvm-br0", "${browser.ip}", 24, "10.100.0.1", "${browser.mac}"),
        ("lan", "fixture-lan", "192.0.2.2", 24, "192.0.2.1", "02:00:00:00:01:04"),
    ]
    for args in clients:
        machine.succeed("${setupClient} " + " ".join(map(str, args)))
    machine.succeed("nft -f ${ruleset}")
    # Simulate Tailscale's earlier INPUT accept. The raw guard must still deny.
    machine.succeed("iptables -I INPUT 1 -i tailscale0 -j ACCEPT")
    machine.succeed("mkdir -p /mnt/{snowfall,avalanche,media,consume,denied}")

    def mount(namespace, export, target, server="${serverAddress}", version=4):
        return (
            f"timeout 12 nsenter --net=/run/netns/{namespace} mount -t nfs "
            f"-o vers={version},proto=tcp,retry=0,timeo=10,retrans=1 "
            f"{server}:/srv/nfs-fixture/{export} /mnt/{target}"
        )

    def connect(namespace, address, port):
        return f"ip netns exec {namespace} nc -z -w 1 {address} {port}"

    with subtest("declared clients read and write only their intended exports"):
        for namespace, export, target in [("snowfall", "transfers", "snowfall"), ("avalanche", "transfers", "avalanche"), ("snowfall", "media", "media"), ("paperless", "consume", "consume")]:
            server = "10.100.0.1" if namespace == "paperless" else "${serverAddress}"
            machine.succeed(mount(namespace, export, target, server))
            machine.succeed(f"grep -q fixture-data /mnt/{target}/seed")
            command = shlex.quote(f"echo {namespace} > /mnt/{target}/{namespace}; cat /mnt/{target}/{namespace}; rm /mnt/{target}/{namespace}")
            machine.succeed(f"setpriv --reuid=1100 --regid=1100 --clear-groups sh -c {command}")
        machine.fail(mount("avalanche", "media", "denied"))
        machine.fail(mount("snowfall", "consume", "denied"))
        machine.fail(mount("paperless", "transfers", "denied", "10.100.0.1"))

    with subtest("root is squashed and cannot bypass server file permissions"):
        machine.fail("cat /mnt/snowfall/root-only")
        machine.fail("touch /mnt/snowfall/root-owned")
        machine.succeed("touch /mnt/snowfall/root-probe/squashed")
        machine.succeed("test $(stat -c %u:%g /srv/nfs-fixture/transfers/root-probe/squashed) = 65534:65534")

    with subtest("undeclared peers and other interfaces cannot reach NFS"):
        machine.fail(connect("other", "${serverAddress}", 2049))
        machine.fail(connect("firefox", "10.100.0.1", 2049))
        machine.fail(connect("lan", "192.0.2.1", 2049))
        # Even a matching source address on an unrelated interface is denied.
        machine.succeed("ip -n lan addr add ${snowfallAddress}/32 dev eth0")
        machine.fail("ip netns exec lan nc -z -w 1 -s ${snowfallAddress} 192.0.2.1 2049")
        machine.fail(mount("other", "transfers", "denied"))

    with subtest("only NFSv4 over TCP is available and RPC helper ports are closed"):
        versions = machine.succeed("cat /proc/fs/nfsd/versions").split()
        assert "+4" in versions, versions
        assert not any(value.startswith(("+2", "+3")) for value in versions), versions
        machine.fail("ss -lun | grep -Eq ':2049[[:space:]]'")
        machine.fail(mount("snowfall", "transfers", "denied", version=3))
        for port in [111, 4000, 4001, 4002]:
            machine.fail(connect("snowfall", "${serverAddress}", port))
            machine.fail(connect("paperless", "10.100.0.1", port))
        machine.succeed("ip -6 addr add fd00:7228::1/64 dev tailscale0 nodad; ip -n snowfall -6 addr add fd00:7228::2/64 dev eth0 nodad")
        machine.succeed("ip netns exec snowfall ping -6 -c 1 -W 2 fd00:7228::1")
        machine.fail("ip netns exec snowfall nc -6 -z -w 1 fd00:7228::1 2049")

    with subtest("the Paperless grant retains host management denial"):
        machine.succeed("systemd-run --unit nfs-host-management ${pkgs.socat}/bin/socat TCP-LISTEN:2222,reuseaddr,fork EXEC:${pkgs.coreutils}/bin/cat")
        machine.wait_for_unit("nfs-host-management.service")
        machine.fail(connect("paperless", "10.100.0.1", 2222))
        machine.fail(connect("firefox", "10.100.0.1", 2222))

    with subtest("firewall reload and restart preserve the NFS source boundary"):
        for action in ["reload", "restart"]:
            machine.succeed(f"systemctl {action} firewall.service")
            machine.succeed("iptables -I INPUT 1 -i tailscale0 -j ACCEPT")
            machine.succeed(connect("snowfall", "${serverAddress}", 2049))
            machine.succeed(connect("paperless", "10.100.0.1", 2049))
            machine.fail(connect("other", "${serverAddress}", 2049))
            machine.fail(connect("firefox", "10.100.0.1", 2049))
  '';
}
