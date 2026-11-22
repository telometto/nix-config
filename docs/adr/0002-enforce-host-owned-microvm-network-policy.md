# Enforce a host-owned MicroVM network policy

## Status

Accepted. Blizzard is configured for `enforce` in the current host
configuration. The preceding audit window and its explicit approval are
recorded in the dated deployment report; `audit` remains the declarative
rollback mode.

## Context

Most Blizzard MicroVM taps share `microvm-br0`. A root-compromised guest can
send arbitrary Ethernet and ARP frames, so guest firewalls alone do not protect
the proxy-to-guest path or one guest from another. In particular, an attacker
could claim Blizzard's `10.100.0.1` identity, influence bridge forwarding, or
send peer-destined traffic to Blizzard's MAC and have the host route it back out
the same bridge.

Bridge-port isolation does not express the required graph: isolated ports can
still communicate with non-isolated ports, while the WireGuard VM must remain a
gateway for designated clients and a small media-service graph needs direct,
private service connections.

## Decision

`modules/virtualisation/microvm-base.nix` owns one declarative policy whenever
the MicroVM host is enabled. The external interface is intentionally small:

- `sys.virtualisation.microvm.networkPolicy.mode` is `enforce` by default and
  can be set to `audit` temporarily.
- `instances.<source>.networkPolicy.allowedPeers.<target>` selects the target's
  registry primary TCP service and/or explicit TCP/UDP ports and requires a
  non-empty operational reason.
- Registered VM gateways are derived from registry IP/gateway relationships;
  callers do not duplicate WireGuard MAC, IP, tap, or port details. The same
  relationship makes each enabled client unit require, start after, and be
  reactivated with its gateway.

The implementation compiles that intent into two narrow native nftables tables
loaded atomically by `microvm-network-policy.service`:

- The `bridge` table validates each enabled tap's registered Ethernet and ARP
  identity, and validates IPv4 source identity for ordinary VMs. The derived
  WireGuard gateway intentionally skips that ordinary source-IP check so it
  can originate traffic for its VPN clients; its host-input path remains
  constrained. The table rejects unknown `vm-*` taps, IPv6, and other
  EtherTypes; permits ARP only where a declared peer path requires it; allows
  stateful, direction-specific service flows; derives WireGuard client pairs;
  and blocks undeclared broadcast/multicast. In `audit`, only otherwise-valid
  undeclared unicast between registered taps is logged, counted, and accepted.
- The `inet` table unconditionally drops host-routed traffic from
  `microvm-br0` back to itself and traffic routed between MicroVM bridges. The
  normal NixOS firewall continues to own host `INPUT`, and existing iptables
  NAT, port forwards, Cloudflare Tunnel, Traefik, LAN, and Tailscale paths remain
  unchanged.

The host tap lifecycle installs a non-aging static registry MAC-to-tap FDB entry
on every enabled tap. Networkd disables unknown-unicast and multicast flooding
and installs permanent registry IP-to-MAC neighbors on Blizzard's bridge
interfaces. Learning remains enabled and ports remain unlocked. The policy
loads before tap setup and VM startup; a failed ruleset transaction leaves the
previous table intact and prevents affected VMs from starting.

Dedicated-bridge VMs cannot receive peer exceptions. Blizzard remains a trusted
control plane and may initiate traffic to guests, subject to each guest's
firewall. Guest access to Blizzard remains subject to the normal NixOS host
firewall. Peer ICMP is not implicitly granted.

## Consequences

Root in an ordinary VM no longer permits claiming another registered MAC, ARP,
or IPv4 identity, observing unknown unicast floods, or routing around the
Layer-2 policy through Blizzard. A compromised WireGuard VM remains deliberately
privileged with respect to its derived VPN clients, but not other VMs. A new VM
has no lateral permissions by default.

Manual edges are host-local and fail evaluation when their source or target is
unknown, disabled, identical, dedicated, missing a reason, missing ports, or
duplicates a port. Legitimate backend traffic remains direct and private rather
than being forced through public hostnames or reverse proxies.

The policy does not add backend TLS/mTLS or general QoS. Those remain separate
defense-in-depth decisions.

The WireGuard guest provides a second fail-closed layer for its privileged
gateway role. It uses a stable fwmark for a firewall-owned OUTPUT kill switch,
rejects forwarded client traffic not leaving through the tunnel, keeps the
firewall active until after `wg-quick` stops, and sizes conntrack explicitly for
the observed qBittorrent workload.

## Rollout and rollback

Blizzard first ran with `networkPolicy.mode = "audit"` while the seven-day
window was reviewed. The first 2026-08 audit iteration was explicitly accepted
after about three days as a one-time exception; its findings and remediations
are recorded in the dated audit report. The current configuration is now
`enforce`. During future changes, inspect the relevant `lateral_drops` or
historical `lateral_audit` counters, probe the declared media and WireGuard
paths, and keep the previous NixOS generation ready for rollback.

The supported escape hatch is declarative: return to `audit` or boot/switch to
the previous generation. There is no mutable bypass command and stopping the
policy service does not remove its tables.
