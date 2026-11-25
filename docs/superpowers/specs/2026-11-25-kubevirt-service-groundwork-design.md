# Groundwork for independent MicroVM migration agents

Status: implementation scope authorized by the user's request for per-service
branches/PRs, including partial wiring and agent handoffs. Implementation choices
below are the builder's calls under that authorization; no runtime deployment is
approved. This extends the validated Actual/Searx pattern.

## Intent and scope

Prepare reviewable host/application groundwork for every currently enabled,
non-Plex-only MicroVM. Eighteen production VM declarations exist. Tautulli is
excluded (Plex-only); SearxNG already has its paired preview PRs; Actual is an
existing reference. The sixteen new IDs are bazarr, cross-seed, firefox, gitea,
immich, jellyfin, matrix-synapse, seerr (legacy overseerr), pocket-id, prowlarr,
qbittorrent, radarr, readarr, sabnzbd, sonarr and wireguard. Seerr is retained for
Jellyfin integration. Disabled registry services are outside this batch.

Keep all production definitions, routes, disks, identities and processes intact.
Do not merge PRs or branches, force-push, activate, reboot, apply manifests, resume
Flux or access protected credentials/application data. Backups remain deferred;
rsync.net is the later destination. Excluding Tautulli does not retire its VM.

## Approaches and selected boundary

Full implementations now would require unavailable private peers, credentials,
media ownership and live device/VPN tests. Documentation-only branches would not
supply the requested wiring. The selected middle boundary is valid, fail-closed
infrastructure groundwork with explicit runtime gates and service-owned files.
The existing Searx preview remains the runtime-tested example.

## Shared foundation and branch structure

Create `dev/kubevirt-groundwork` in both repositories. The host foundation builds
on `dev/kubevirt-base` (#7320); the application foundation builds on the existing
`dev/kubevirt-searxng` (#13). Each service has `dev/kubevirt-<id>` in both repos,
with paired draft PRs targeting the corresponding groundwork foundation.
Existing Searx PRs are reused; no duplicate service PRs are opened.

The application foundation registers all sixteen pairs of suspended Flux layers
in a separate `migration-layers.yaml` resource. It provides valid empty storage
and app kustomizations for each reserved path. Service branches replace only
their own directories. This avoids conflicting edits to a global registration
list when the PRs are stacked. Empty slots are explicitly reservation slots,
not claimed implementations. Each new service PR must add real manifests.

The host foundation provides a public catalog, canonical registration generator
and public Nix contracts. Per-service host modules contain only a disabled
preview disk registration; the normal module loader discovers them. Exact CI
path mappings may select this dedicated contract while retaining global Nix
evaluation. Unmapped runtime files and CI control changes retain full coverage.

## Per-service groundwork

Use `<id>-preview` namespaces and disjoint retained directories under
`/flash/enc/vms/kubevirt-pilot/<id>-preview/<disk>`. The root is a fresh 20 GiB PVC
using the already pinned public Debian container disk and CDI node pulling.
Declare blank retained data PVCs for reviewed application state volumes; catalog
entries distinguish these from legacy OS persist disks and external shares.
Nothing imports or mounts a production image, library, credential or host device.
Future storage sizing/ownership and restore work remain explicit gates.

Preserve declared CPU/memory and a private primary service port where applicable.
WireGuard uses its declared UDP port; do not claim native TCP port-forwarding can
forward UDP. Secondary ports, peer access and gateway behavior remain per-service
work. PVs use Retain, layers use prune=false, host registrations are false and
VM runStrategy is Halted. Source/schema correctness must not imply application
readiness: the groundwork VM uses an explicit failing exec readiness probe
(`/usr/bin/false`) until a future agent implements real service readiness.

Storage owns the namespace, default-deny and narrowly scoped CDI importer policy.
Application ingress permits only the probe namespace and the kubevirt namespace
AND virt-api pod selector, on the declared private service port/protocol.
Guest egress remains denied, including VPN-dependent guests; importers may fetch
the pinned root via DNS/public HTTPS. No public edge, host networking, privileged
host device or unrestricted private network access is added.

Attach a read-only ConfigMap configuration ISO with a public plan and runtime
script. A common first-boot seed installs stable named-NIC DHCP and a per-boot
loader. The loader refuses runtime execution unless the service ID matches and
runtimeReady is boolean true. The shipped runtime script itself exits with a
clear unimplemented status. It installs nothing, formats nothing and reads no
credentials. A fresh agent can replace only its service-owned script and plan,
then use a reviewed Git stop/start to consume configuration on the retained root.
No application image is invented or represented as already functional. Native
service startup, secret delivery and real readiness must be implemented before
runtime acceptance; the selected guest OS/image may be revised then.

## Ownership, validation and handoff

The catalog records public declaration provenance, legacy state/shares and
service-specific gates. New agents own only their service host registration and
application directory; shared generators, catalogs, root layers and production
VM files belong to the coordinator unless separately assigned. Use isolated
worktrees and explicit file staging. Co-author, commit and push finished work;
keep every PR draft and auto-merge disabled.

Public tests exercise every reserved path and every populated service: pinned
CRDs/CEL, suspended/halted state, private peers, denied guest egress, retained and
disjoint volumes, unique short disk serials, loader refusal/identity validation
and unchanged host configuration when registrations are disabled. Negative
controls reject enabled host files, extra host side effects, symlinks and unsafe
paths. Build the shared host closure and the complete application contract;
per-service commits run their meaningful public contracts. Verify stackability
of all service deltas without merging any branch.

Save the handoff index, reusable agent template and one assignment document per
service in a fresh OS temporary directory, outside the workspaces. Include a
suggested-skills section and a checklist; reference specs, catalog, commits,
PRs and per-service plans instead of copying them. Do not include credentials,
private account details or runtime user data. Each assignment states its owned
paths, exact branch/base/PRs, tests, service-specific gates and stop-before-live
boundary. Read-only source/build verification and new fixture tests are allowed;
production-data access and deployment require separate user authorization.

## Acceptance boundary

Groundwork is complete when all sixteen paired service PRs and both foundation
PRs exist with real code, tests and agent assignments, and no production mutation
has occurred. This does not establish VM application functionality, real Flux/CDI
reconciliation, PVC permissions, media access, identity preservation after an
actual migration, VPN leak protection or GPU operation. Those items are explicit
future checklist gates. A separately approved live preview comes before any
production cutover or retirement.
