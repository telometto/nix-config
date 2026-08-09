# Blizzard deployment audit — 2026-08-08

## Revalidation update — 2026-08-09

A read-only follow-up at 2026-08-09 10:21 CEST found the deployed network
policy healthy after 4 days and 20 hours. The live policy `ExecStart` exactly
matches this checkout's evaluated nftables command and ruleset store path. All
relevant MicroVM units are active.

The kernel journal now contains 3,616 audit messages, still exclusively the
understood Prowlarr-to-Arr TCP `5355` pattern:

| Flow | Messages |
| --- | ---: |
| Prowlarr -> Sonarr TCP 5355 | 1,458 |
| Prowlarr -> Readarr TCP 5355 | 1,441 |
| Prowlarr -> Radarr TCP 5355 | 717 |

There are zero journal events for spoofing, unknown taps, gateway bypass,
routed bypass, or enforced lateral drops. Fresh HTTP probes passed in both
directions between Prowlarr and Sonarr, Radarr, and Readarr. qBittorrent,
SABnzbd, and Firefox still use `10.100.0.11` as their default gateway and all
three reached an external HTTPS endpoint.

WireGuard remains healthy at 4,912 of 32,768 conntrack entries, with no
`nf_conntrack: table full` messages. The firewall entered active state before
`wg-quick-wg0`, both units remain successful, and an external route lookup uses
`wg0` table/fwmark `51820`.

The root-only counter snapshot supplied later on August 9 completed the final
evidence gate:

| Counter | Packets | Assessment |
| --- | ---: | --- |
| `spoof_drops` | 0 | Pass |
| `unknown_tap_drops` | 0 | Pass |
| `gateway_bypass_drops` | 0 | Pass |
| `routed_lateral_drops` | 0 | Pass |
| `lateral_audit` | 3,980 | Consistent with the investigated TCP 5355 pattern |
| `invalid_drops` | 19,970 | Expected enforced invalid/unsupported traffic |
| `multicast_drops` | 1,073 | Expected undeclared multicast traffic |

The operator explicitly accepted ending the second audit window early rather
than waiting until 2026-08-11 at approximately 14:21 CEST. With every observed
undeclared lateral flow classified, no suspicious identity or bypass events,
and the positive service and VPN probes passing, the evidence supports moving
Blizzard to `enforce`. Scrutiny and the acknowledged Readarr/Exportarr
compatibility error are separate service-health issues and do not block this
decision.

## Scrutiny remediation update — 2026-08-09

The follow-up moved to `main`, where the collector loopback fix was already
present. Scrutiny now also uses `127.0.0.1` for its InfluxDB client and consumes
the renamed `scrutiny/token` SOPS secret through a service-scoped systemd
credential. The root-only SOPS file is not made readable by Scrutiny's dynamic
user, and the token value is not rendered into the Nix store.

The `nix-secrets` input was advanced to commit `6b01eb6`, which contains the
renamed key. A focused regression check and the full Blizzard system closure
both build successfully. Runtime authentication remains unproven until this
configuration is deployed: if the reused token does not belong to the existing
InfluxDB authorization database, Scrutiny will continue to report
`unauthorized` and a recovery or replacement token will still be required.

## Conclusion

The deployed MicroVM audit policy is functioning and the WireGuard hardening
is live. The later root-only counters are satisfactory, and the operator
explicitly accepted the shortened window. The branch can therefore set
`networkPolicy.mode = "enforce"`; deployment and post-deployment verification
remain separate operator actions.

The 3,175 `microvm-policy audit:` messages are one understood pattern rather
than missing service edges: Prowlarr's VM resolver is attempting TCP 5355
(LLMNR) toward the Arr VMs. All four VMs have systemd-resolved listening on
5355 and report `+LLMNR`; the application services listen on their normal
ports. No new policy edge should be added for this traffic.

There are two separate operational findings. This branch predates Scrutiny's
main-branch collector endpoint fix, and the deployed service lacks valid
InfluxDB authentication. Readarr has emitted a recurring SQLite
`SHOW server_version` syntax error while its exporter polls it every five
seconds; that remains an upstream compatibility issue.

## Scope and snapshot

- Checkout: `security/microvm-networking-hardening`, commit `34a193ea`
  (`34a193eaac863961c757d99961888c15deb4d3d8`); worktree was clean before
  this report was added.
- Host: `blizzard` at `192.168.2.100`; snapshot `2026-08-08T19:36:34+02:00`.
- Current boot: `2026-08-04 14:21 CEST`.
- Policy service: started `2026-08-04 14:21:28 CEST`, exited successfully,
  and remains active as a `RemainAfterExit` unit.
- Live host generation:
  `26.05.20260803.531670d`, nixpkgs revision
  `531670d871c0e29724a02f3cbcac170adc65b58c`.
- No remote configuration, restart, switch, firewall mutation, or service
  change was performed. The live pings and HTTP requests below were
  read-only path probes.

## Evidence

| Area | Observed | Assessment |
| --- | --- | --- |
| Policy loading | `microvm-network-policy.service` is active/exited with result `success`; all 16 MicroVM units and TAP setup units are running/active | Pass |
| Bridge identity | 15 shared-bridge taps are up; static registry FDB entries are present for each shared identity | Pass |
| Audit events | 3,175 total; 1,290 Prowlarr→Sonarr, 620 Prowlarr→Radarr, 1,265 Prowlarr→Readarr, all TCP destination port 5355 | Investigated; no edge to add |
| Hard-deny events | 1,813 IPv6 invalid drops, 13,850 TCP invalid-state drops, and 170 ARP multicast drops | Expected enforced controls; no spoof/unknown-tap/bypass events |
| WireGuard conntrack | `nf_conntrack_count=5313`, `nf_conntrack_max=32768`; no `table full` messages | Pass |
| WireGuard ordering | Firewall active before `wg-quick-wg0`; both succeeded since boot | Pass |
| Routed service path | qBittorrent→WireGuard ICMP succeeded; WireGuard→qBittorrent TCP 11030 returned HTTP 200 and TCP 50820 connected | Pass; reverse ICMP is guest-firewall denied |
| Declared Prowlarr edges | Requests from Prowlarr to ports 11021, 11022, and 11024 returned HTTP 302 | Pass |
| Host health | `scrutiny-collector.service` failed; collector could not connect to `0.0.0.0:11001` | Follow-up required |

## Findings and interpretation

### 1. The shortened audit window was explicitly accepted

The policy generation started on August 4 at 14:21:28 CEST. The ordinary
seven-day observation point would be August 11 at approximately 14:21 CEST.
After reviewing the August 9 root-only counters, the operator explicitly
accepted the shorter observation window. The event distribution at the
original snapshot was:

```text
2026-08-04  443
2026-08-05  661
2026-08-06  756
2026-08-07  749
2026-08-08  566 at the snapshot
```

### 2. TCP 5355 is resolver/LLMNR traffic, not a missing application edge

The branch explicitly keeps TCP 5355 out of the enforce ruleset and tests
that Arr-to-Prowlarr LLMNR access is denied. The live audit messages are the
opposite direction, Prowlarr-to-Arr, and occur only on port 5355.

Live checks found:

- systemd-resolved owns the 5355 listeners in Prowlarr, Sonarr, Radarr, and
  Readarr VMs; each link reports `+LLMNR`.
- Prowlarr listens on 11020; Sonarr, Radarr, and Readarr listen on 11021,
  11022, and 11024 respectively.
- Prowlarr's normal application requests reach the Arr ports. The service
  logs show normal HTTP synchronization, and direct probes returned 302.
- There were no audit events on the declared application ports.

Disposition: classify the 5355 events as expected resolver noise under audit,
do not add a peer exception, and verify after an explicitly approved move to
`enforce` that normal Prowlarr synchronization remains healthy.

### 3. Identity and lateral-bypass controls show no incidents

The current-boot journal contained zero messages for:

- `spoof-drop`
- `unknown-tap`
- `gateway-bypass`
- `routed-drop`

The IPv6 and ARP drops are consistent with the declared policy rejecting
unsupported guest IPv6 and undeclared broadcast/ARP delivery. The TCP
invalid-state messages are dominated by qBittorrent traffic to and from
external peers through `vm-wireguard`; the packet flags and destinations look
like late or invalid connection-state packets. That attribution is an
evidence-based inference from the kernel log, not process-level packet
attribution.

### 4. WireGuard hardening is live

The WireGuard VM reported:

- `nf_conntrack_max=32768`, with current count `5313`;
- `wg-quick-wg0` and `firewall.service` both successful and active since boot;
- policy routing of `1.1.1.1` through `wg0`, with fwmark rule `51820`;
- no kernel `nf_conntrack: table full` messages since deployment.

qBittorrent's default route is via `10.100.0.11`. qBittorrent can reach the
gateway, and the gateway can reach qBittorrent's explicitly permitted WebUI
and torrent TCP ports. A reverse ICMP ping fails because the shared MicroVM
baseline has `allowPing = false`; peer ICMP is not implicitly granted. This
is guest-firewall behavior, not evidence that the host gateway pair rule is
broken.

### 5. Separate service-health findings

#### Scrutiny: endpoint and InfluxDB credentials require remediation

The initial collector failure at `2026-08-08 00:00:09 CEST` was reported as
an attempt to reach `http://0.0.0.0:11001/api/devices/register`. The live
follow-up showed that this was not the primary failure: `scrutiny.service`
was itself in a restart loop, and its startup log ended with
`panic: unauthorized: unauthorized access` while opening the Scrutiny
repository. `scrutiny-collector.service` then failed because the web API was
not available.

The live InfluxDB health endpoint returned 200 and setup reported
`allowed: false`, confirming an initialized database. Unauthenticated
organization and bucket requests returned 401, while the InfluxDB journal
repeated `authorization not found` and `token required`. The generated
Scrutiny configuration has no usable InfluxDB org, bucket, or token. The
current host declaration sets only the Scrutiny port and firewall/proxy
options, so no credential can be inferred safely from this repository.

This was remediated later on `main`: both local client destinations are now
`127.0.0.1`, and the existing authorization value was renamed to
`scrutiny/token` and wired as a root-only, service-scoped credential. The
following post-deployment checks remain required:

```bash
sudo systemctl status scrutiny.service scrutiny-collector.service influxdb2.service --no-pager
sudo journalctl -u scrutiny.service -u scrutiny-collector.service -u influxdb2.service -b --no-pager \
  -g 'unauthorized|token required|Timeout|collector'
curl --fail http://127.0.0.1:8086/health
curl --fail http://127.0.0.1:11001/api/health
sudo systemctl start scrutiny-collector.service
```

The full closure proves that the renamed SOPS key exists and can be installed,
but only deployment can prove that its value matches an active authorization
in the existing InfluxDB database. Do not reset the database or disable its
authentication if that runtime check fails.

#### Readarr: upstream compatibility; left unchanged

On Readarr, `readarr.service` and its exporter are running and `/ping` returns
HTTP 200, but Readarr logs a SQLite error near `SHOW server_version` every
five seconds. The exporter is polling Readarr endpoints at the same cadence.
Readarr is [archived upstream](https://github.com/Readarr/Readarr), and the
[next major Exportarr line removes Readarr support](https://github.com/onedr0p/exportarr/pull/428).
Disabling only this exporter would hide metrics rather than fix Readarr, so
this follow-up is left unchanged and should be handled as an upstream
migration/retirement decision.

### 6. Full generation provenance is not independently confirmed

The live policy unit's exact `ExecStart` and rendered ruleset store paths
match the values produced by evaluating this checkout, and the live behavior
is clearly `audit`. The full system toplevel does not match the local
checkout's current evaluated toplevel because the host uses nixpkgs
`531670d`, while this branch's lock currently selects nixpkgs-beta
`2f5a153c270b70cb0f8c11f46d96d6d3bc39f4e3`; the deployed system also exposes
no branch commit in `configurationRevision`.

This may be intentional if the authoritative deployment checkout advanced
its lockfile, but it means the host cannot be treated as a byte-for-byte
provenance match for the whole branch from the available metadata. Record the
deployment checkout and lock revision before the enforce change.

## Root-only verification completed

The SSH account `zeno` is in `wheel`, but noninteractive sudo reported that a
password is required. The operator subsequently supplied the output of these
commands:

```bash
sudo nft list counters table bridge microvm_policy
sudo nft list counters table inet microvm_policy
```

The counters are recorded in the revalidation section above. All identity and
bypass counters were zero; `lateral_audit` was consistent with the classified
TCP 5355 traffic. This completes the pre-enforcement root-only gate.

## Recommendation

1. Deploy the separately approved `enforce` configuration in a maintenance
   window and retain the current audit generation for rollback.
1. Do not add a TCP 5355 edge.
1. Deploy the completed main-branch Scrutiny credential and loopback wiring,
   then verify both Scrutiny units and the absence of InfluxDB authorization
   errors. This is not a MicroVM enforcement prerequisite.
1. Leave the Readarr/exporter loop unchanged pending an upstream migration or
   retirement decision.
1. After deployment, verify that the policy service loaded the enforce
   ruleset, TCP 5355 increments `lateral_drops`, Prowlarr synchronization still
   works, and both directions of the WireGuard-routed service path remain
   healthy.
