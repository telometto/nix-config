# Boot the actual socket/template, account, PAM, sudo, and kernel firewall.
# The synthetic tailscale0 link does not exercise tailscaled or live policy.
{ pkgs, consts }:
let
  target = consts.tailscale.hosts.snowfall.ipv4;
  scanner = consts.tailscale.hosts.sandfly.ipv4;
  other = "100.90.0.1";
  port = 22022;
  fixtureKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoJQoGpAoRuSbAoQTdCbGRc3xJQ77aCpHwoXTjpSiHp runtime-placeholder";
in
pkgs.testers.runNixOSTest {
  name = "sandfly-runtime";
  nodes.machine = {
    imports = [ ../modules/security/sandfly-target.nix ];
    _module.args = { inherit consts; };
    services.openssh.enable = true;
    services.tailscale.enable = true;
    # No external account, credentials, or network access in this fixture.
    systemd.services.tailscaled.enable = false;
    sys.security.sandflyTarget = {
      enable = true;
      tailscalePolicyReady = true;
      listenAddress = target;
      scannerAddress = scanner;
      inherit port;
      authorizedKeys = [ fixtureKey ];
    };
    environment.systemPackages = [ pkgs.openssh ];
  };
  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("sandfly-sshd.socket")
    machine.wait_for_unit("sshd.service")
    # FreeBind must permit startup before the exact address/interface exists.
    machine.fail("ip link show tailscale0")
    machine.succeed("ss -ltn | grep -F '${target}:${toString port}'")

    machine.succeed("ip netns add scanner")
    machine.succeed("ip link add tailscale0 type veth peer name scan0")
    machine.succeed("ip link set scan0 netns scanner")
    machine.succeed("ip addr add ${target}/32 dev tailscale0")
    machine.succeed("ip link set tailscale0 up")
    machine.succeed("ip route add ${scanner}/32 dev tailscale0")
    machine.succeed("ip route add ${other}/32 dev tailscale0")
    machine.succeed("ip -n scanner link set lo up")
    machine.succeed("ip -n scanner addr add ${scanner}/32 dev scan0")
    machine.succeed("ip -n scanner addr add ${other}/32 dev scan0")
    machine.succeed("ip -n scanner link set scan0 up")
    machine.succeed("ip -n scanner route add ${target}/32 dev scan0")

    # Generate disposable private keys inside the VM. Replace only the public
    # key payload in the module's rendered root-owned file; retain restrictions.
    empty_passphrase = shlex.quote("")
    for name in ("old", "new", "foreign"):
        machine.succeed(f"ssh-keygen -q -t ed25519 -N {empty_passphrase} -f /tmp/{name}")
    original = machine.succeed("cat /etc/ssh/sandfly-authorized_keys").strip()
    restrictions = original.split(" ssh-ed25519 ", 1)[0]

    def install_keys(names):
        lines = [restrictions + " " + machine.succeed(f"cat /tmp/{name}.pub").strip() for name in names]
        content = shlex.quote("\n".join(lines) + "\n")
        machine.succeed(f"printf %s {content} > /tmp/authorized_keys")
        machine.succeed("rm -f /etc/ssh/sandfly-authorized_keys")
        machine.succeed("install -o root -g root -m 0444 /tmp/authorized_keys /etc/ssh/sandfly-authorized_keys")

    def ssh(key="old", user="sandfly", source="${scanner}", listener=${toString port}, command="true"):
        # Never let SSH consume the test driver's command channel as stdin.
        return (
            "timeout 15 ip netns exec scanner ssh -n -F /dev/null -o BatchMode=yes "
            "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
            "-o IdentitiesOnly=yes -o ConnectTimeout=3 "
            f"-b {source} -i /tmp/{key} -p {listener} {user}@${target} {shlex.quote(command)}"
        )

    install_keys(["old"])
    machine.succeed(ssh(command="test $(id -un) = sandfly"))
    machine.succeed(ssh(command="test $(/usr/local/bin/sudo -n id -u) = 0"))
    machine.fail(ssh(key="foreign"))
    machine.fail(ssh(user="root"))
    machine.fail(ssh(user="nobody"))
    machine.fail(ssh(source="${other}"))
    machine.fail(ssh(listener=22))
    machine.succeed("journalctl -u 'sandfly-sshd@*' --no-pager | grep -F 'Accepted publickey for sandfly'")

    # Exercise the internal-sftp subsystem and a writable scanner home.
    machine.succeed("printf 'upload probe' > /tmp/probe")
    machine.succeed("printf 'put /tmp/probe /home/sandfly/probe\\nget /home/sandfly/probe /tmp/download\\n' > /tmp/sftp-batch")
    machine.succeed(
        "timeout 15 ip netns exec scanner sftp -F /dev/null -b /tmp/sftp-batch "
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o IdentitiesOnly=yes -o BindAddress=${scanner} "
        "-i /tmp/old -P ${toString port} sandfly@${target}"
    )
    machine.succeed("cmp /tmp/probe /tmp/download")

    install_keys(["old", "new"])
    machine.succeed(ssh(key="old"))
    machine.succeed(ssh(key="new"))
    install_keys(["new"])
    machine.fail(ssh(key="old"))
    machine.succeed(ssh(key="new"))

    for action in ("reload", "restart"):
        machine.succeed(f"systemctl {action} firewall.service")
        machine.wait_for_unit("sandfly-sshd.socket")
        machine.succeed(ssh(key="new"))
        machine.fail(ssh(key="new", source="${other}"))
  '';
}
