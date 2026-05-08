# Trigger VM — Troubleshooting Log

**Date:** 2026-05-08\
**VM:** `trigger-vm` (`admin@10.100.0.80`)\
**Reported issue:** `trigger-ch-migrate-fixup.service` fails → `trigger-compose.service` never starts.

______________________________________________________________________

## Symptom

```
× trigger-ch-migrate-fixup.service - Repair trigger.dev ClickHouse goose migration state before stack startup
     Active: failed (Result: exit-code)
    Process: ExecStart=…trigger-ch-migrate-fixup-start (code=exited, status=81)

May 08 08:28:20 trigger-vm trigger-ch-migrate-fixup-start[2334]:
  Code: 81. DB::Exception: Database trigger_dev does not exist. (UNKNOWN_DATABASE)
```

`trigger-compose.service` is `inactive (dead)` because its `Requires=` on the fixup service was not satisfied.

______________________________________________________________________

## Initial Code Analysis (from nix-config)

The relevant service is defined in `modules/services/trigger.nix`.

The `trigger-ch-migrate-fixup` script:

1. Starts only the ClickHouse container (`docker compose up -d clickhouse`).
1. Waits up to 60 s for it to become healthy.
1. Extracts `CLICKHOUSE_PASSWORD` from `/run/trigger/compose.env`.
1. Defines a helper `ch()` that runs `clickhouse-client --database trigger_dev`.
1. Uses `ch()` for the **very first check** — a query against `system.tables`:
   ```bash
   GOOSE_TABLE=$(ch "SELECT count() FROM system.tables WHERE database='trigger_dev' AND name='goose_db_version'")
   [ "$GOOSE_TABLE" = "0" ] && exit 0
   ```

**Root-cause hypothesis (pre-SSH):** The `ch()` helper passes `--database trigger_dev` to every invocation of `clickhouse-client`. On a fresh install (or after a data-volume wipe) the `trigger_dev` database does not yet exist. The intent is to detect this case (`GOOSE_TABLE = 0`) and bail early, but the `--database` flag forces ClickHouse to switch to `trigger_dev` *before* running the query, producing exit code 81 (`UNKNOWN_DATABASE`) before the result can be returned. The early-exit guard never fires.

______________________________________________________________________

## SSH Investigation

### Step 1 — Service status (already known from user report)

```
trigger-setup.service   → active (exited) — SUCCESS
trigger-ch-migrate-fixup.service → failed (exit-code 81)
trigger-compose.service → inactive (dead, dependency failed)
```

### Step 2 — Confirmed root cause of fixup failure

SSH'd into `blizzard` via Tailscale, then `ssh admin@10.100.0.80`.

```
# SHOW DATABASES inside ClickHouse → trigger_dev does not exist (fresh install)
# Confirms hypothesis: ch() passes --database trigger_dev before the DB exists
# → ClickHouse throws UNKNOWN_DATABASE (exit 81) before the query runs
```

**Fix applied** in `modules/services/trigger.nix`: added a prior check using
`system.databases` (no `--database` flag) before calling `ch()`. Skips the
entire script when the database does not yet exist.

### Step 3 — Manually started the stack, discovered networking failure

Bypassed the fixup service and ran `docker compose up -d` manually. All 9
containers started, but `trigger-webapp-1` immediately crash-looped with:

```
Error: P1001: Can't reach database server at `postgres:5432`
```

Prisma migration cannot connect to postgres. Tested with upstream
trigger.dev compose files in `/tmp/trigger-test/` — identical failure,
confirming this is an environmental issue, not specific to our Nix config.

### Step 4 — Network diagnostics

| Test | Result |
|---|---|
| `nslookup postgres` from webapp network | Resolves to `172.19.0.3` ✓ |
| `nc -w3 -zv postgres 5432` | **Hangs** (no SYN-ACK) |
| `nc -w3 -zv 172.19.0.3 5432` (by IP) | **Hangs** |
| `ping 172.19.0.3` from same network | **No reply** |
| `postgres listen_addresses` | `'*'` (all interfaces) |
| `ip_forward` | `1` (enabled) |
| `iptables -L FORWARD` | `policy ACCEPT`, DOCKER-FORWARD chain present |
| `bridge link show` | **Empty** — no ports attached to ANY bridge |
| `/sys/class/net/br-960e0a746dc5/brif/` | **Empty** — confirmed at sysfs |

Docker had created bridge interfaces (`br-*`) and veth pairs, but **never
attached the veths as bridge slaves**. This is the structural reason no
inter-container traffic could flow — even ICMP was blocked.

### Step 5 — Root cause identified: systemd-networkd matching Docker veths

The routing table revealed the cause:

```
default via 10.100.0.1 dev vethcca6681 proto static   ← wrong!
default via 10.100.0.1 dev veth84d50bc proto static   ← wrong!
10.100.0.0/24 dev vethcca6681 src 10.100.0.80         ← wrong!
...
```

`systemd-networkd` was matching every Docker veth interface because
`/etc/systemd/network/20-lan.network` uses `matchConfig.Type = "ether"`,
which also matches veth link-type interfaces. This caused two problems:

1. **networkd "claimed" each veth**, preventing Docker from running
   `ip link set vethXXX master br-YYY` — hence `brif/` always empty.
1. **Route table pollution** — the VM's static LAN routes were injected into
   every new veth, breaking Docker's own routing.

Secondary blocker also found: `base.nix` sets `rp_filter = 1` (strict), which
would additionally drop inter-container packets even if the bridge were
attached, because return packets arrive on the bridge but the routing table
routes the source subnet via the veth.

______________________________________________________________________

## Fix

### Fix 1 — `trigger-ch-migrate-fixup` (code complete, needs rebuild)

File: `modules/services/trigger.nix`

Added a prior check against `system.databases` (no `--database` flag) before
calling `ch()`. This correctly handles a fresh install where `trigger_dev` does
not yet exist.

### Fix 2 — systemd-networkd veth match (code complete, needs rebuild)

File: `vms/mkMicrovmConfig.nix`

Replaced the broad `Type = "ether"` match with a precise MAC-address match so
only the VM's virtio NIC receives the static LAN config:

```nix
matchConfig.MACAddress = mac;
```

Added a `"99-docker-ignore"` network unit that marks `veth*`, `br-*`, and
`docker*` interfaces as `Unmanaged = true` for defense in depth.

### Fix 3 — rp_filter (code complete, needs rebuild)

File: `modules/services/trigger.nix`

Added a `sys.services.trigger.looseRpFilter` option (defaults to `true`).
When enabled, it sets `net.ipv4.conf.all.rp_filter = 2` (loose) scoped only
to the system that enables the trigger service. `vms/base.nix` keeps the
strict default (`rp_filter = 1`) for all other VMs — only trigger-vm gets
loose mode, because Docker bridge networking creates asymmetric routing that
strict mode drops.

### Live workaround (applied on the VM, not persistent across rebuild)

```bash
# 1. Create a networkd ignore file with higher priority (sorts before 20-lan)
#    and correct permissions
sudo bash -c 'cat > /etc/systemd/network/10-docker-ignore.network << EOF
[Match]
Name=veth* br-* docker*

[Link]
Unmanaged=yes
EOF'
sudo chmod 644 /etc/systemd/network/10-docker-ignore.network
sudo networkctl reload

# 2. Lower rp_filter to loose mode
sudo sysctl -w net.ipv4.conf.all.rp_filter=2 net.ipv4.conf.default.rp_filter=2

# 3. Restart Docker so new veths use the corrected networkd rules
sudo systemctl restart docker
```

After applying: `bridge link show` shows all veth slaves in `forwarding`
state, and `nc -w3 -zv postgres 5432` returns `open` from within the webapp
network.

> **NOTE:** The live workaround file `/etc/systemd/network/10-docker-ignore.network`
> and the `sysctl` changes are NOT persistent across a reboot or NixOS rebuild.
> The proper fix is in the Nix config (see fixes 2 and 3 above) and must be
> deployed via a NixOS rebuild on Blizzard once CI validates it.

______________________________________________________________________

## Remaining work

- [ ] Deploy all three fixes via NixOS rebuild on Blizzard (requires SSH to
  Blizzard with rebuild permissions, or push to `main` and let CI build).
- [ ] After rebuild, wipe `/tmp/trigger-test/` and re-run the native
  `trigger-compose.service` (not the upstream test) to confirm end-to-end.
- [ ] Monitor that `trigger-ch-migrate-fixup.service` succeeds on the first
  boot after the rebuild (fresh `trigger_dev` database).
