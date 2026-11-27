# SearxNG private KubeVirt preview

This is a fresh private preview, not a production migration. As committed,
`sys.virtualisation.actualPilot.previewVMs.searx-preview.enable` is false and both
Flux layers are suspended. Rebuilding this branch as-is does not create a Searx
preview directory, import its disk or start its VM. The production `searx`
MicroVM and its `search` publication keep their existing definitions.

## Review and deployment order

The host stack is `dev/kubevirt` -> `dev/kubevirt-base` ->
`dev/kubevirt-searxng`. PR #5894 retains `dev-kubevirt` as its compatibility head.
The companion homelab-apps branch is also `dev/kubevirt-searxng`. All PRs stay
draft; no merge or activation is part of this preparation.

After review, a separately authorized deployment needs these steps:

1. Land the reviewed host base/service changes and the suspended application
   definitions in their intended source branches. Keep the canonical umbrella and
   #5894 compatibility head synchronized with fast-forward pushes.
1. Make a reviewed host-only change setting
   `sys.virtualisation.actualPilot.previewVMs.searx-preview.enable = true`.
   Build Blizzard's complete toplevel and compare `dry-activate` against its
   running generation. Stop if it would interrupt production MicroVMs. Enabling
   the guard changes k3s preStart; a live activation may restart k3s. Neither
   `nix build` nor source validation authorizes that restart.
1. Record the 18 running production MicroVM identities/PIDs and available storage
   and RAM before the authorized boot/activation. After host preparation succeeds,
   confirm the new root directory is empty and the guard accepted its ownership.
   Do not clear a guard failure by deleting or moving an existing image.
1. In Git, set `suspend: false` only for `pilot-searx-storage` in
   `clusters/blizzard-actual-pilot/layers.yaml`. Wait for its DataVolume to report
   `Succeeded` and its PVC to be Bound. It depends on CDI and owns the preview's
   default-deny/importer policy; the application can remain suspended throughout.
1. In a second Git change, resume `pilot-searx`. It depends on KubeVirt and
   `pilot-searx-storage`. Wait for VM Ready, guest-agent connection, HTTP readiness
   and Flux Ready. First boot installs signed Debian dependencies and pulls the
   pinned official application image; later cached boots need no registry.
1. Test private forwarding, searches, preferences, rate limiting and cache
   connectivity. Compare the production MicroVM PIDs and public search endpoint
   with the recorded baseline. A local smoke test does not prove live CDI,
   KubeVirt, NetworkPolicy or source reconciliation on Blizzard.

## Paths and access

| Item | Preview-only value |
|------|--------------------|
| Namespace / VM | `searx-preview` / `searx-preview` |
| Retained PV / PVC / DataVolume | `searx-preview-root` |
| Host root directory | `/flash/enc/vms/kubevirt-pilot/searx-preview/root` |
| Guest application state | `/var/lib/searx-preview` on this retained root |
| Public desired configuration | `searx-preview-desired` ConfigMap, mounted read-only at `/run/searx-preview-config` |
| Guest-local signing key | `/var/lib/searx-preview/secret.env`, generated once, mode 0600 |
| Guest-local cache | Valkey at `127.0.0.1:6379`, nonpersistent, bounded to 128 MiB |
| HTTP | ClusterIP TCP 8080, one vCPU / 2 GiB guest RAM |

No production path is moved, copied, mounted or overwritten. The preview needs a
new 20 GiB root PVC plus the VM's memory overhead. Registration metadata is held
outside its PV by the [shared guard](kubevirt-preview-base.md). Deleting the
cluster DB with retained images intentionally blocks reimport.

From a desktop, after authorized deployment:

```bash
ssh -t -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:18080:127.0.0.1:18080 zeno@192.168.2.100 \
  'sudo actual-pilot-virtctl -n searx-preview port-forward --address=127.0.0.1 vmi/searx-preview 18080:8080'
```

Leave the tunnel open and visit `http://127.0.0.1:18080`. Native forwarding is
allowed only from `virt-api` pods in namespace `kubevirt`; the probe namespace is
also permitted. The network policy blocks private networks, tailnet ranges and
metadata addresses from outgoing web requests. Valkey is never exposed through
a Kubernetes Service or guest network listener. No public edge route is added.

## Git-managed changes and acceptance

Desired image/settings/limiter configuration live in homelab-apps under
`clusters/blizzard-actual-pilot/searx-preview/app`. The image is pinned to an
official immutable digest. No real signing key is present in Git, cloud-init,
a ConfigMap or a Kubernetes Secret; the seed Secret contains public provisioning.

A ConfigMap update does not update the disk of a running VMI. Commit a visible
settings change, let Flux apply it, then commit `runStrategy: Halted`, wait for
Stopped/Flux Ready, and commit `runStrategy: Always`. Confirm the new setting on
the same root/PVC and unchanged guest identity metadata. Repeat with a tested
pinned image reference, then reverse the change through the same Git power cycle.
Check cached-image startup while registry access is unavailable. Image and
settings rollback uses the previous reviewed Git revision; it does not replace
the retained disk.

The generic runner/bootstrap and base OS remain first-boot provisioning. Editing
cloud-init does not upgrade an already initialized guest. Such changes need a
separate guest-update or replacement-root procedure; this preview does not claim
a Git-driven OS upgrade pipeline.

The current settings retain POST search, image proxying, the limiter, engine
preferences and weights. The pinned SearxNG version uses plugin class names;
legacy Hostname replace/Hostnames settings map to its single Hostnames plugin.
The limiter uses the new botdetection setting names and trusts no caller-supplied
IP headers on this direct private endpoint. Public HTTP/HTTPS egress supports
search and proxied images; this does not grant access to private production APIs.

## Stop and rollback gates

If a preview fails, keep production Searx as the rollback. To stop only the
preview, commit `runStrategy: Halted`, wait for Stopped, then suspend the app
layer in Git. Suspension alone does not stop a running VM. Keep the retained
storage and its namespace; every layer uses `prune: false` and every PV Retain.
Disabling the host registry does not delete an image or stop an existing VM.

Before any production cutover, complete live search/private-access and Git
update/reversal acceptance, an explicit route/auth review, and the separately
planned backup/restore gate. Off-host backups remain deferred; rsync.net is the
selected destination. Other workloads are queued in [the migration matrix](kubevirt-migrations.md).
