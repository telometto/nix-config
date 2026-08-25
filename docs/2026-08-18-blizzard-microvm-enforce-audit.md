# Blizzard MicroVM enforce-mode audit

Initial audit: 2026-08-18
Final evidence and closure: 2026-08-22
Scope: Blizzard host and its MicroVM network-policy enforcement after switching the host to `enforce` mode.

## Executive verdict

Blizzard is operationally enforcing the MicroVM network policy. The deployed
ruleset is active, loaded successfully before the MicroVMs, and has the exact
same SHA-256 as the ruleset rendered from the current checkout. The live
topology also matches the declared registry: 16 running MicroVMs, 15 taps on
`microvm-br0`, and the dedicated `pocket-id` bridge.

The audit found no evidence of a spoofing, unknown-tap, gateway-bypass, or
routed-lateral bypass. Declared service paths worked, while undeclared
MicroVM-to-MicroVM paths timed out as expected. The focused NixOS policy test,
flake evaluation, statix check, and full Blizzard toplevel build all passed.

The seven-day post-enforcement observation is now closed. The operator-supplied
counter snapshot from 2026-08-22 shows zero spoof, unknown-tap,
gateway-bypass, routed-lateral, and audit-mode accepts. The nonzero counters
are expected rejected invalid, multicast, and undeclared-lateral traffic.

One provenance note remains: the deployed full-system generation is older than
the current checkout's evaluated generation. The policy artifact itself
matches exactly, but full generation provenance should still be recorded.

There is no source-level remediation indicated by this audit. Keep the policy
in `enforce` mode. The security and operational acceptance gates are closed;
only full deployed-generation provenance remains as a follow-up recordkeeping
item.

## Scope and method

All remote commands I ran were read-only and ran as `zeno` over SSH. I
inspected the host's systemd, nftables rule artifact, bridges, taps, FDB
entries, neighbors, routes, conntrack state, and current-boot journal. I also
ran read-only HTTP, route, ping, and external-connectivity probes from
selected guests. The operator separately supplied the two root-only nft
counter outputs documented below.

I did not generate spoofed packets, alter firewall state, reload services,
activate a configuration, restart a VM, or run destructive commands. The
identity-spoof and routed-bypass cases were covered by the repository's
focused NixOS test instead.

## Evidence snapshot

| Item | Observation |
| --- | --- |
| Host | `blizzard` |
| NixOS generation on host | `26.05.20260814.02e0898` |
| Current boot | `2026-08-14 18:57:41 CEST` to the snapshot |
| Policy service start | `2026-08-14 18:58:02–03 CEST` |
| Runtime snapshot | `2026-08-18 14:35:18 CEST` |
| Policy observation age at initial snapshot | Approximately 3 days 19 hours 37 minutes |
| Seven-day observation threshold | `2026-08-21 18:58:03 CEST` |
| Final counter snapshot | Operator-supplied on `2026-08-22`; exact time not supplied |
| Live policy artifact | `/nix/store/6rb9k6xsp45w7xnnhfdpg3lxs3s57pkq-microvm-network-policy.nft` |
| Live policy SHA-256 | `b6f40364e46649df6412934704da3b2f309448ea0b6d2b805173f285454281d1` |
| Current-checkout rendered policy SHA-256 | Same as live: `b6f40364e46649df6412934704da3b2f309448ea0b6d2b805173f285454281d1` |
| Active MicroVMs | 16 |
| Active MicroVM taps | 16 |

## Source and build validation

The host explicitly sets `networkPolicy.mode = "enforce"` in
[`hosts/blizzard/virtualisation/microvms.nix`](../hosts/blizzard/virtualisation/microvms.nix#L331).
The shared module keeps identity, unknown-tap, unsupported-EtherType,
multicast, and routed-isolation checks hard-enforced, and exposes `audit` only
as an explicit rollback mode in
[`modules/virtualisation/microvm-base.nix`](../modules/virtualisation/microvm-base.nix#L720-L731).
The policy compiler selects `drop` and the `lateral_drops` counter for
undeclared lateral traffic in
[`lib/microvm-network-policy.nix`](../lib/microvm-network-policy.nix#L108-L111).

The following local checks passed:

| Check | Result |
| --- | --- |
| `git diff --check` | Passed |
| `nix flake check --no-build` | Passed; all checks evaluated |
| `nix build .#checks.x86_64-linux.microvm-network-policy --no-link --print-build-logs` | Passed; positive, negative, spoof, routed-isolation, gateway, IPv6, and unknown-tap cases exercised |
| `nix run 'nixpkgs#statix' -- check .` | Passed |
| `nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link --print-build-logs` | Passed |

The local checkout evaluated to
`nixos-system-blizzard-26.05.20260817.0dd31db`, while the host is running the
August 14 generation. This is a provenance difference, not a policy mismatch:
the rendered policy SHA-256 is identical on both sides.

## Runtime findings

### 1. Policy service ordering and hardening — pass

`microvm-network-policy.service` was `active (exited)` with
`Result=success` and `ExecMainStatus=0`. It ran the expected
`nft --file /etc/microvm-network-policy/ruleset.nft` command. The unit is
ordered before the MicroVM and tap units and uses the expected service
hardening (`CAP_NET_ADMIN` only, `NoNewPrivileges`, `PrivateTmp`,
`ProtectHome`, and `ProtectSystem=strict`). Sampled MicroVM properties showed
the required policy-service dependencies.

The live ruleset contained both bridge and inet policy tables, including the
`undeclared_lateral` drop path and the `deny_routed_lateral` drop path. The
presence of both `lateral_audit` and `lateral_drops` counters is expected from
the generated ruleset; the active undeclared-lateral chain uses the enforced
drop verdict and `lateral_drops`.

### 2. Bridge, identity, and tap isolation — pass

All 16 running VMs had the expected tap attached to the expected bridge:

- 15 guests use `microvm-br0` at `10.100.0.0/24`;
- `pocket-id` uses the dedicated `pocket-id-br0` at `10.100.1.0/30`;
- every tap was forwarding with learning enabled and unicast/multicast flood
  disabled; and
- every enabled tap had a matching static FDB entry for its declared guest
  MAC, plus a permanent host neighbor entry for its declared guest IP/MAC.

This confirms the host-side identity and topology state needed by the policy;
it does not by itself constitute a live forged-packet test.

### 3. Declared and undeclared service paths — pass

Read-only guest probes produced the expected split:

| Probe | Result |
| --- | --- |
| Prowlarr to Sonarr, Radarr, and Readarr | HTTP `302` |
| Sonarr/Radarr/Readarr to Prowlarr | HTTP `302` |
| Sonarr/Radarr/Readarr to qBittorrent | HTTP `200` |
| Sonarr/Radarr/Readarr to SABnzbd | HTTP `303` |
| Prowlarr or Arr guests to undeclared Gitea | Timed out; curl `28`, HTTP `000` |
| Prowlarr or Arr guests to undeclared TCP/5355 | Timed out; curl `28`, HTTP `000` |
| WireGuard guest to declared qBittorrent path | HTTP `200` |
| WireGuard guest to undeclared Gitea | Timed out; curl `28`, HTTP `000` |

The focused NixOS test additionally verified directional service rules,
gateway-bypass drops, same-bridge and dedicated-bridge routed drops, forged
MAC/IP/ARP rejection, IPv6 rejection, and unknown-tap rejection.

### 4. WireGuard gateway and conntrack — pass

qBittorrent had the expected default route through the WireGuard guest and
could reach the external HTTPS probe with HTTP `200`. The WireGuard guest had
the expected policy-routing rule (`fwmark 51820` / table `51820`), a default
route through `wg0`, and firewall/tunnel ordering with the firewall before
`wg-quick`.

At the snapshot, conntrack usage was:

- host: `7166 / 262144`;
- WireGuard guest: `5078 / 32768`; and
- the WireGuard guest had no current-boot `nf_conntrack: table full` kernel
  entries.

This is healthy capacity evidence. The final policy counter snapshot below
closes the post-enforcement observation gate.

### 5. Current-boot policy telemetry — informational, no bypass indicated

The readable current-boot journal contained these policy-message counts:

| Prefix | Count |
| --- | ---: |
| `microvm-policy invalid-drop:` | 11,695 |
| `microvm-policy lateral-drop:` | 2,884 |
| `microvm-policy multicast-drop:` | 351 |
| spoof-drop | 0 |
| unknown-tap drop | 0 |
| gateway-bypass drop | 0 |
| routed-lateral drop | 0 |

The lateral-drop traffic was dominated by Prowlarr-to-Arr-family TCP/5355
traffic, matching the previously observed discovery/noise pattern. The
invalid-drop traffic was dominated by qBittorrent/WireGuard TCP teardown
traffic and guest IPv6/UDP traffic. These are rejected at the intended policy
boundaries; they do not show a bypass. Do not add TCP/5355 to the declared
service graph solely to remove this noise.

These are journal-event counts, not nft counter snapshots. The root-only nft
snapshot is recorded below.

### 6. Final nft counter snapshot — pass

The operator supplied the output of both root-only counter commands on
2026-08-22. No counter reset was reported, so these are treated as the
cumulative post-enforcement snapshot:

| Counter | Packets | Bytes | Assessment |
| --- | ---: | ---: | --- |
| `spoof_drops` | 0 | 0 | No forged registered identity observed |
| `invalid_drops` | 24,401 | 1,389,048 | Invalid/unsupported traffic rejected |
| `unknown_tap_drops` | 0 | 0 | No unregistered tap traffic observed |
| `multicast_drops` | 2,197 | 61,516 | Undeclared multicast/broadcast traffic rejected |
| `gateway_bypass_drops` | 0 | 0 | No VPN gateway bypass observed |
| `lateral_audit` | 0 | 0 | No undeclared traffic accepted in audit mode |
| `lateral_drops` | 5,558 | 344,708 | Undeclared lateral traffic rejected in enforce mode |
| `routed_lateral_drops` | 0 | 0 | No routed lateral bypass observed |

These counters provide the missing root-level evidence and are consistent with
the earlier read-only guest probes and journal telemetry.

## Acceptance matrix

| Gate | Status | Evidence |
| --- | --- | --- |
| Blizzard source mode is `enforce` | Pass | Host module and evaluated configuration |
| Generated policy behavior | Pass | Focused `microvm-network-policy` NixOS test |
| Flake evaluation | Pass | `nix flake check --no-build` |
| Static analysis | Pass | statix |
| Blizzard system build | Pass | Full toplevel build |
| Live policy service | Pass | Successful active/exited unit, correct `ExecStart` |
| Live/source policy artifact parity | Pass | Exact SHA-256 match |
| VM/tap topology and static identities | Pass | 16 units, FDB and neighbor checks |
| Declared paths | Pass | Guest HTTP probes |
| Undeclared paths | Pass | Guest timeout probes and enforced drop chain |
| WireGuard gateway path | Pass | Routing, firewall ordering, allowed/denied probes |
| Hard-drop journal evidence | Pass | Zero spoof/unknown/gateway/routed journal events |
| Live nft packet counters | Pass | Operator-supplied snapshot; all bypass categories are zero |
| Seven-day post-enforce observation | Pass | Threshold passed on 2026-08-21 18:58:03 CEST; final counters supplied on 2026-08-22 |
| Full deployed-generation provenance | Partial | Policy artifact matches; full generation differs |

## Recommendations

1. Keep Blizzard in `enforce` mode. No source fix is indicated.
1. Record the supplied counter snapshot with the deployment evidence. For any
   future ruleset reload, record the reload time and counter reset explicitly.
1. Record the deployed flake commit and lock revision at the next deployment
   or audit handoff so the full system generation can be reconciled with the
   evaluated checkout.
1. Preserve the existing focused test as the acceptance gate for future policy
   changes. Do not run live spoofing or bypass traffic against production just
   to fill this report's evidence matrix.

## Root-only evidence supplied by the operator

The operator ran these commands on Blizzard and supplied the output used to
close the counter evidence:

```console
sudo nft list counters table bridge microvm_policy
sudo nft list counters table inet microvm_policy
```
