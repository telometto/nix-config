# Sandfly Target Operations

Snowfall and Blizzard enable `sys.security.sandflyTarget` for agentless scans
through a dedicated OpenSSH listener on TCP 2222. Human Tailscale SSH remains
on TCP 22. The targets can remain user-owned and retain access to shared Kaizer.

The `sandfly` account has unrestricted passwordless sudo. A scanner credential
that authenticates successfully is effectively root on its target. Sandfly
uploads its forensic binary into a randomly named directory in the account's
writable home; a sudo allowlist for user-writable executables would not provide
a meaningful root boundary. See Sandfly's [protected-system requirements](https://docs.sandflysecurity.com/docs/protected-system-requirements)
and [operational FAQ](https://docs.sandflysecurity.com/docs/operational-faq).

## Policy prerequisite

Before activation, review the **live** tailnet policy. `tailscalePolicyReady`
records an operator confirmation; it cannot inspect the policy. Existing `true`
settings are not evidence that the live policy has passed migration checks.

Human Tailscale SSH must allow only `zeno` with periodic reauthentication and
deny `sandfly` and `root`. Remove broader additive SSH rules that allow humans
to select `autogroup:nonroot` on these hosts: a narrow rule cannot override
broader permissions. OpenSSH's `DenyUsers` does not govern Tailscale SSH.

During migration, separately review a transitional network grant from the
scanner's exact address to the two exact target addresses on TCP 2222. Retain
only old scanner access required for the transition. After both scans succeed,
the final policy must remove scanner access to TCP 22 and other destinations.
Do not replace the live policy with the final policy before the listeners work.

Follow the complete migration order in
[`tailscale_acls/docs/sandfly-openssh-migration.md`](https://github.com/telometto/tailscale_acls/blob/main/docs/sandfly-openssh-migration.md).
This checkout implements the host preparation stage, not policy deployment,
device ownership changes, or Sandfly target registration.

## Host configuration and credentials

Addresses and port come from `lib/constants.nix`:

| Role | IPv4 | Scan port |
| --- | --- | --- |
| Snowfall target | `100.67.190.43` | `2222` |
| Blizzard target | `100.85.254.99` | `2222` |
| Sandfly scanner source | `100.116.146.113` | — |

Each target has its own Sandfly-generated Ed25519 credential. The public keys
are declared in the corresponding host configuration; private keys remain in
Sandfly's credential manager. Select `sandfly_snowfall` for Snowfall and
`sandfly_blizzard` for Blizzard, both with login username `sandfly`.

Example host declaration:

```nix
sys.security.sandflyTarget = {
  enable = true;
  tailscalePolicyReady = true; # Only after reviewing the human SSH policy.
  listenAddress = consts.tailscale.hosts.snowfall.ipv4;
  authorizedKeys = [ "ssh-ed25519 PUBLIC_KEY_FROM_SANDFLY" ];
};
```

`scannerAddress` defaults to `consts.tailscale.hosts.sandfly.ipv4`, and `port`
defaults to `consts.ports.host.sandflySsh`. No manual module imports are needed.

The module provides:

- A locked-password account with a private writable home and no extra groups.
- A separate root-managed `/etc/ssh/sandfly-authorized_keys`. Keys are restricted
  to the scanner address and are absent from ordinary authorized-key files.
- An independent configuration at `/etc/ssh/sandfly_sshd_config`, accepting
  only `sandfly` from the scanner address, using public-key authentication.
- Disabled password and keyboard-interactive authentication, root login,
  forwarding, tunnels, user SSH startup scripts, and user-supplied environment
  files. Command execution and file transfer remain available for scans.
- A `sandfly-sshd.socket` bound only to the target IPv4. `FreeBind` permits
  startup before the address appears; the socket survives Tailscale restarts
  and address removal/reappearance. Connections start `sandfly-sshd@` services.
- A raw PREROUTING source guard before Tailscale's INPUT acceptance. Only the
  scanner address through `tailscale0` to this target address can pass. Other
  sources/interfaces and local IPv6 delivery to the scan port are dropped.
  Forwarded subnet traffic is outside this guard.
- An interface-specific firewall port allowance, with no global port opening.
  Reloads fail closed while rules are rebuilt; firewall restarts also restart
  the dependent socket.
- A `DenyUsers sandfly` restriction on ordinary OpenSSH, while retaining human
  Tailscale SSH and reconciling `tailscale set --ssh` on service activation.
- Passwordless sudo and `/usr/local/bin/sudo` linked to the NixOS sudo wrapper,
  refusing to overwrite an unrelated administrator-managed path.

The dedicated listener uses the host's existing
`/etc/ssh/ssh_host_ed25519_key`. Verify its public key through a trusted console
before accepting it in Sandfly. The account requires PAM for key authentication
with a locked password; the module asserts that ordinary OpenSSH/PAM, Tailscale,
the iptables firewall, and the standard Ed25519 host-key declaration are enabled.

Forwarding restrictions constrain SSH features; they cannot contain commands
or network connections launched by an account that can become root. Shell-only,
SFTP-only, chroot, and service restrictions that prevent sudo or forensic access
would break the intended scanning operation.

## Build before activation

Build from this checkout without applying the configuration:

```bash
git diff --check
nix build --no-link 'path:.#checks.x86_64-linux.sandfly-target'
nix build --no-link 'path:.#nixosConfigurations.snowfall.config.system.build.toplevel'
nix build --no-link 'path:.#nixosConfigurations.blizzard.config.system.build.toplevel'
```

These commands require the private flake input. `path:.` includes new files
before they are staged. The focused check evaluates both hosts, rejects invalid
configuration combinations, parses effective listener settings with OpenSSH,
validates the public keys, and exercises firewall reload, source rotation, and
failure behavior through a command/packet model. It does not boot a host or
prove live Tailscale policy, authentication, or Sandfly scans.

## Verification after staged activation

Activate one host at a time only after the transitional policy has been
reviewed. Use the migration guide for activation and recovery commands.

On the target, inspect the exact listener, effective configuration, and host key:

```bash
sudo ss -ltnp 'sport = :2222'
sudo sshd -T -f /etc/ssh/sandfly_sshd_config
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
sudo iptables -t raw -S PREROUTING
sudo iptables -t raw -S SANDFLY_SSH
sudo ip6tables -t raw -S PREROUTING
```

The listener must be exactly `100.67.190.43:2222` or `100.85.254.99:2222`, never
`0.0.0.0`, `::`, a LAN address, or a guest address. A systemd-owned listening
socket is expected even when no scan session is running.

In Sandfly, configure each target's verified IPv4, username `sandfly`, its
matching credential, port 2222, and the trusted host key. Run a complete scan
and verify root-only inspection. Check each key fails on the other host, root
and other usernames fail on the scan listener, and `sandfly` cannot log in
through ordinary OpenSSH or human Tailscale SSH.

From a different human tailnet device, both commands must fail:

```bash
nc -vz -w 5 100.67.190.43 2222
nc -vz -w 5 100.85.254.99 2222
```

A connection denied by the tailnet policy alone does not prove the host guard;
verify its rules/counters or perform a separately reviewed transitional test
that actually delivers the denied probe to the target.

Using the recovery console, test firewall reload/restart, Tailscale restart,
and host reboot, then repeat a scan and human-source rejection:

```bash
sudo systemctl reload firewall.service
sudo systemctl restart firewall.service
sudo systemctl restart tailscaled.service
sudo systemctl status sandfly-sshd.socket --no-pager
sudo journalctl -u 'sandfly-sshd@*' --no-pager -n 100
```

Also verify human `zeno` access and the existing Kaizer, Immich, Jellyfin, and
NFS paths specified in the migration guide before applying the final policy.

## Credential rotation and rollback

Rotate credentials per host in Sandfly, update only that host's `authorizedKeys`,
build and activate the reviewed configuration, and verify the new key works
and the retired key fails. An overlap with both public keys can be declared
briefly if needed; remove the retired key after validation.

To disable a target, set `sys.security.sandflyTarget.enable = false` and rebuild.
The listener, dedicated key file, account declaration, and sudo rule disappear.
Activation removes the compatibility link only if this module owns it and it
still points to the NixOS sudo wrapper. Existing home data is not erased.

Firewall stop leaves an early deny in place deliberately. Disabling the module
does not immediately erase those raw deny rules; reboot clears them. This
avoids reopening a stale scan listener during rollback. Do not repurpose TCP
2222 until the old listener is stopped and the remaining guard is reconciled.

For a failed staged migration, use the previously recorded system generation
and recovery console as described in the migration guide. Recheck the policy:
rolling back the host can restore the earlier Tailscale SSH scanning design.
