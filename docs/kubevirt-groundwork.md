# Independent KubeVirt migration groundwork

The groundwork prepares independent review branches for the sixteen enabled
services listed in [the public catalog](../lib/kubevirt-groundwork/catalog.json).
Tautulli is excluded because it is Plex-only. Seerr remains in scope for Jellyfin;
its production VM and state retain the legacy name `overseerr`. Existing Tautulli
and other production definitions are untouched. SearxNG has its existing preview
PRs; Actual remains the accepted reference.

## Stack and ownership

Host changes stack as `dev/kubevirt` (compatibility PR #5894 head
`dev-kubevirt`) → `dev/kubevirt-base` → `dev/kubevirt-groundwork` → independent
`dev/kubevirt-ID`. Application changes stack as `dev/kubevirt-searxng` →
`dev/kubevirt-groundwork` → independent `dev/kubevirt-ID`. The individual service
PRs are siblings, not a sequence. Stack their disjoint service directories after
review; merging or deploying any part requires separate authorization.

Each service owns `hosts/blizzard/virtualisation/ID-preview.nix` and
`clusters/blizzard-actual-pilot/migrations/ID/` in homelab-apps. The shared catalog,
generators, reserved Flux layers and tests belong to the coordinator. Future
runtime host wiring belongs in a separate, unmapped file so it receives full CI.

## Generate a host registration

From this checkout, after creating the service branch from its groundwork base:

```bash
python3 lib/kubevirt-groundwork/generate.py bazarr \
  --output hosts/blizzard/virtualisation/bazarr-preview.nix
```

The generator refuses to overwrite an existing file or symlink. It emits a
canonical default-false disk registration. The application scaffold uses the
same catalog and fresh disk names. It never reads the catalog's legacy images,
external shares or credentials. Legacy `/persist` identity is a migration design
input, not a new PVC or a permission to copy host/guest keys.

All proposed disks are fresh and retained below
`/flash/enc/vms/kubevirt-pilot/ID-preview/DISK`. No directory is prepared until an
explicit host enablement and later activation. The isolated retained-disk guard
refuses unknown populated directories. Sizes reflect configured budgets, not
measured usage: notably Immich declares a 1 TiB data budget and Firefox a 512 GiB
download budget. Check available space and filesystem overhead before resuming
any storage layer. Off-host backups to rsync.net remain deferred.

## What a service PR establishes

A service PR adds real stopped infrastructure: private service, VM, independent
storage and restrictive policies. Its host preparation is false, both Flux
layers are suspended and the VM is halted. The configuration plan has
`runtimeReady: false`; the owned runtime script refuses to start. The readiness
probe deliberately fails until a real application check is implemented. This
is source/build groundwork, not a working application preview or deployment.

No production data, secret, share, device, VPN route, public edge or legacy
service is changed. Guest egress is denied. The importer alone may use DNS and
public HTTPS to fetch the pinned fresh root. WireGuard declares UDP; TCP virtctl
port-forwarding is not a WireGuard acceptance method.

## Validation and next agent

Run the public host contract without importing the private host flake:

```bash
nix-build --no-out-link --expr \
  'import ./tests/kubevirt-groundwork-check.nix { nixpkgs = builtins.fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/0dc498bfe49baeb18b0f9891e800b53bb2603193.tar.gz"; sha256 = "sha256-s/0jq8usZtLVOolYBwmyUmd3JsfAu7w3FU+a0dgMqSY="; }; }'
PYTHONDONTWRITEBYTECODE=1 python3 .github/tests/test_flake_ci.py
```

The contract requires exact canonical module source and regular file/parent
directory metadata. It rejects context-dependent host side effects and proves
that disabled registrations leave pilot preparation, firewall, Traefik and a
production VM service unchanged. It also checks all sixteen hypothetical enabled
path sets. Selective CI keeps global Nix evaluation for each registration file;
unknown host/runtime changes use the full suite.

See the [design](superpowers/specs/2026-11-25-kubevirt-service-groundwork-design.md)
and [execution plan](superpowers/plans/2026-11-25-kubevirt-service-groundwork.md).
Per-service public plans live in the corresponding homelab-apps directory.
Temporary handoffs reference those authoritative artifacts and carry an agent
checklist. Each next agent must implement and pin the real runtime, design safe
credential/state delivery and replace failing readiness before requesting live
preview authorization. Disk/data, API/OIDC, media/hardlink, VPN/kill-switch,
GPU and database/identity acceptance depend on that service. Production cutover
and old VM retirement remain separate decisions.
