# Blizzard HTTP detection and client attribution

## Scope and status

The first source implementation for R-02 restores message-only Traefik journal
acquisition and narrows forwarded-header trust to the local Cloudflare Tunnel.
It also retains the User-Agent header needed by the configured HTTP scenarios.
This work can proceed while R-03 waits for Matrix live acceptance. Deploying
this shared edge change still requires the Matrix coordination and observation
gates in [the security sequence](security-roadmap-implementation-order.md).

R-02 remains **In progress**. Persistent local retention, an off-host retention
destination with independent recovery access, auditd execution telemetry, and
live detection/remediation evidence remain outstanding. This implementation
adds no logging backend, provider changes, secrets, or deployment. The older
`2026-08-13-blizzard-intrusion-audit.md` referenced by the roadmap is absent
from this checkout and is not used as acceptance evidence.

## Client-IP contract

The public path is Cloudflare edge → cloudflared → `localhost:80` on Blizzard
→ Traefik → workload. Direct LAN and Tailscale clients are callers, not
forwarding proxies.

| Boundary | Contract |
| --- | --- |
| Traefik `web` and `websecure` | Accept forwarded headers only from `127.0.0.1/32` and `::1/128`; `insecure = false`. Discard forwarded headers supplied by other socket peers. |
| Access log | JSON on stdout, acquired from `traefik.service`. `ClientAddr` preserves the socket peer; `ClientHost` contains the sanitized X-Forwarded-For chain, or the peer when no chain survives. |
| CrowdSec acquisition | `journalctl --output=cat` supplies the JSON message without the journal's timestamp, hostname, and program prefix. Keep `journalctl` available in the service PATH. |
| CrowdSec parser | The upstream Traefik parser selects the last, trimmed `ClientHost` chain component as `source_ip`. Verify the installed parser before activation; Hub content is updated at service startup and is not pinned by `flake.lock`. |
| Traefik bouncer | Read the sanitized `X-Forwarded-For` chain from right to left, skipping only the two trusted loopbacks. Use the socket peer if no external client remains. Do not substitute `CF-Connecting-IP`, which is not stripped by Traefik on direct requests. |
| Header logging | Drop headers by default and retain only `User-Agent`. Authorization, cookies, and Cloudflare Access tokens are not added to access logs. Existing URL/path logging remains unchanged. |

Cloudflare appends the connecting client to an incoming X-Forwarded-For chain;
earlier caller-supplied entries do not establish identity. Cloudflare edge
CIDRs are not immediate peers of this tunnel origin, so they no longer belong
in the bouncer's proxy-skip list. The old monthly edge-IP staleness workflow
has been retired; the flake contract check now guards the actual trust list.

Loopback remains a host trust boundary: a process on Blizzard can impersonate
the local tunnel. These settings do not isolate mutually untrusted host
processes. Expanding the proxy set or adding another upstream proxy requires
a review of all three client-IP consumers and fresh positive/negative tests.

For IPv6 attribution, confirm that Cloudflare Pseudo IPv4 is not configured
to overwrite headers. Any Worker that rewrites client-IP headers also needs
separate validation. Those provider settings are live acceptance prerequisites,
not facts established by this repository change.

## Source validation

```bash
nix build .#checks.x86_64-linux.crowdsec-http --no-link --print-build-logs
nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link
```

The check asserts the effective Blizzard acquisition, access-log, entrypoint,
and bouncer settings. It runs the configured Traefik package against a local
fixture backend to test trusted IPv4/IPv6 requests, spoofed direct headers,
and header omission. It does not contact production or run the runtime-managed
CrowdSec Hub parser or bouncer plugin. Flake evaluation requires private-input
access; Windows HTTP tests alone do not validate NixOS evaluation or deployment.

On 2026-09-05, all 22 HTTP/log cases passed locally against the official
Traefik 3.7.12 Windows binary (archive SHA-256
`f2bb10a353baf11321840d9ce95028a9847eb32b2c39e1905952a7d82f069245`).
That run used synthetic settings matching this change; Nix was unavailable,
so effective Nix configuration evaluation and the Linux flake check remain
pending. No production requests or deployment were performed.

## Live acceptance after approved deployment

Record the configuration revision, flake-lock hash, deployed generation,
Traefik/CrowdSec versions, installed `crowdsecurity/traefik-logs` parser version
and checksum, UTC interval, and client vantage with each result. Keep raw logs
and any sensitive request URLs in operator-controlled evidence storage.

1. Confirm `systemctl show crowdsec -p ExecStart -p Environment` and the
   service's journal show a working journalctl acquisition without a missing
   executable or skipped datasource. Use `cscli metrics show acquisition` to
   capture a before/after count around a uniquely marked benign request.
1. Read that request with
   `journalctl -u traefik.service --since '<UTC start>' --output=cat`.
   Extract the access record (the unit can also emit application diagnostics),
   confirm valid JSON and the expected client chain, and check that credentials
   and cookies are absent from logged headers.
1. Replay a synthetic access record through the installed parser using
   `cscli explain --file <synthetic-json-log> --type traefik -v`.
   Confirm `source_ip`, request method/path/status, and User-Agent fields;
   a read counter alone does not prove successful parsing. Also replay a
   journal-prefixed control record to demonstrate why message-only acquisition
   is required. Do not replay production logs into live decision processing.
1. Send benign public requests from controlled IPv4 and IPv6 clients. Confirm
   the parser and bouncer identify the real client, not loopback, a Cloudflare
   edge, or a fabricated earlier X-Forwarded-For entry. Check the provider
   prerequisites above and preserve the observed chain as evidence.
1. From a direct LAN client and a direct Tailscale client, send requests with
   fabricated `X-Forwarded-For`, `X-Real-IP`, and `CF-Connecting-IP`. Confirm
   the parser and bouncer use the connecting peer. Repeat for reachable IPv6
   paths. A path that is unavailable is recorded as untested, not passed.
1. In an approved controlled test window, verify a short-lived test decision
   blocks only the test client and expires or is removed afterward. Confirm
   normal clients and Matrix availability remain healthy. This is a separate
   live operation, not part of running the flake check.

These results complete the HTTP portion only. Before closing R-02, define and
test journal/audit retention limits, reboot survival, collection gaps and
capacity alerts, off-host delivery and independent retrieval, and auditd
execution coverage and loss counters. Feed that evidence into R-13. A backup
or a passing HTTP request alone is not durable forensic retention evidence.

## Upstream evidence

- [CrowdSec journalctl acquisition](https://docs.crowdsec.net/docs/log_processor/data_sources/journald/)
  supports journalctl arguments in `journalctl_filter`.
- [Traefik 3.7.12 access logging](https://github.com/traefik/traefik/blob/v3.7.12/pkg/middlewares/accesslog/logger.go)
  and [forwarded-header sanitization](https://github.com/traefik/traefik/blob/v3.7.12/pkg/middlewares/forwardedheaders/forwarded_header.go)
  define the pinned access-log boundary.
- [CrowdSec Traefik parser](https://github.com/crowdsecurity/hub/blob/master/parsers/s01-parse/crowdsecurity/traefik-logs.yaml)
  defines source-IP and HTTP metadata extraction; this URL is mutable.
- [Bouncer 1.4.5 IP selection](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/blob/v1.4.5/pkg/ip/ip.go)
  defines the right-to-left proxy-skip behavior.
- [Cloudflare request headers](https://developers.cloudflare.com/fundamentals/reference/http-headers/)
  documents X-Forwarded-For, Pseudo IPv4, and Worker behavior.
