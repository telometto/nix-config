# KubeVirt Migration Plan

This is the execution tracker for migrating every current MicroVM workload on `blizzard` to a KubeVirt `VirtualMachine` managed from `telometto/homelab-apps`.

## Decisions

| Topic | Decision |
|---|---|
| Workload target | Every current MicroVM becomes a KubeVirt VM. No workload is intentionally moved to a shared-kernel Kubernetes container in this migration. |
| GitOps repo | `https://github.com/telometto/homelab-apps` |
| Guest image | Debian Stable cloud image imported with CDI `DataVolume` |
| Storage phase 1 | Single-node local PV/hostPath-backed PVCs on `blizzard` |
| Rollback | Keep the old MicroVM data and unit available until each KubeVirt VM survives validation and a backup cycle |
| gVisor | Out of scope for this all-VM migration; remove/defer `RuntimeClass: gvisor` work |

The first storage phase is intentionally not live-migration-ready. KubeVirt live migration needs storage that can move with the VM or be attached from every node. Do not claim live migration as complete until storage is moved to a shared/distributed design.

## Repositories

| Repo | Responsibility |
|---|---|
| `telometto/nix-config` | NixOS host config, k3s/Cilium/Flux bootstrap, legacy MicroVM source-of-truth during migration |
| `telometto/homelab-apps` | Flux Kustomizations, operators, storage, ingress, NetworkPolicies, KubeVirt VM manifests |
| `telometto/nix-secrets` | Host-level secrets and any bootstrap secrets that must be decrypted by NixOS/sops-nix |

## Current VM inventory

Temporary source-of-truth: `vms/vm-registry.nix` and `hosts/blizzard/virtualisation/microvms.nix`.

| VM | Current enabled | vCPU | RAM | Main port | Public route(s) | Special notes |
|---|---:|---:|---:|---:|---|---|
| `adguard` | no | 1 | 3 GiB | 11010 | `adguard` | DNS service; old forwards include 53 TCP/UDP, 443, 853. Decide LAN/Tailscale/public DNS exposure before cutover. |
| `actual` | no | 1 | 1 GiB | 11051 | `actual` | Good low-risk pilot candidate if data is current. |
| `searx` | yes | 1 | 2 GiB | 11012 | `search` | Public search UI; keep security headers and rate limiting. |
| `ombi` | yes | 1 | 1 GiB | 11041 | `ombi` | Public request UI. |
| `tautulli` | yes | 1 | 1 GiB | 11042 | `tautulli` | Plex-adjacent headers and CrowdSec middleware today. |
| `gitea` | yes | 2 | 2 GiB | 11050 | `git`, `ssh-git` | High-risk: HTTP plus SSH, Git data, LFS/JWT secrets. |
| `sonarr` | yes | 1 | 1 GiB | 11021 | `series` | Media share at `/data`; state image must be copied. |
| `radarr` | yes | 1 | 1 GiB | 11022 | `movies` | Media share at `/data`; state image must be copied. |
| `prowlarr` | yes | 1 | 1 GiB | 11020 | `indexer` | Indexer integrations; validate arr stack connectivity. |
| `bazarr` | yes | 1 | 1 GiB | 11023 | `subs` | Media share at `/data`; subtitle state must be copied. |
| `readarr` | yes | 1 | 1 GiB | 11024 | `books` | Media share at `/data`. |
| `lidarr` | no | 1 | 1 GiB | 11028 | `music` | Disabled today; useful pilot if data is not critical. |
| `qbittorrent` | yes | 1 | 2 GiB | 11030 | none | Privacy-routed today via `wireguard` VM gateway; needs in-guest VPN kill switch or deliberate network design. |
| `overseerr` | yes | 1 | 1 GiB | 11040 | `requests` | Plex-adjacent headers and CrowdSec middleware today. |
| `firefox` | yes | 4 | 4 GiB | 11052 | `ff` | Browser isolation is the product; privacy-routed today. |
| `wireguard` | yes | 1 | 512 MiB | 56943/UDP | raw UDP | Inbound VPN gateway; use MetalLB or equivalent controlled UDP exposure. |
| `sabnzbd` | yes | 1 | 1 GiB | 11031 | `sab` | Privacy-routed today via `wireguard` VM gateway; media share at `/data`. |
| `flaresolverr` | no | 1 | 512 MiB | 11013 | none | Registry entry only; no standalone `flaresolverr-vm` is exported or enabled today. FlareSolverr currently runs inside the `prowlarr` MicroVM. |
| `matrix-synapse` | yes | 4 | 4 GiB | 11060 | `matrix`, apex well-known | High-risk: federation, E2E identity, MAS secrets, Postgres state. |
| `paperless` | no | 4 | 8 GiB | 11061 | `docs` | Sensitive documents; keep CSRF-safe headers and validate document integrity. |
| `firefly` | yes | 2 | 2 GiB | 11062 | `finance` | Finance data; Postgres and app key secrets. |
| `brave` | no | 4 | 4 GiB | 11054 | `brave` | Browser isolation; privacy-routed today. |
| `firefly-importer` | yes | 1 | 512 MiB | 11063 | `finimport` | Finance-adjacent; validate importer auth and Firefly connectivity. |
| `immich` | no | 4 | 8 GiB | 11070 | `photos` | Large photo library; 1 TiB state image, Postgres state, integrity checks required. |
| `mealie` | yes | 1 | 1 GiB | 11071 | `recipes` | Public route with security headers and CrowdSec middleware today. |

## Implementation phases

### Phase 0 — Stabilize `nix-config`

- [ ] Keep Cilium-only k3s flags gated behind `sys.services.k3s.ciliumCni`.
- [ ] Ensure `sys.services.k3s.bootstrap` removes stale Flux auth manifests when `fluxGitAuthSecretFile` is unset.
- [ ] Install Cilium before Flux and verify pod-to-ClusterIP API connectivity before Flux starts.
- [ ] Keep gVisor out of the bootstrap path.
- [ ] Remove merge-conflict backup docs and stale tiered-container language.
- [ ] Do not delete MicroVM files until all KubeVirt VMs are proven.

### Phase 1 — Bootstrap cluster operators

- [ ] k3s runs on `blizzard` with Cilium native routing and kube-proxy replacement.
- [ ] Flux reconciles `telometto/homelab-apps`.
- [ ] `homelab-apps` has dependency-ordered Kustomizations for namespaces, network, sealed-secrets, ingress, KubeVirt, CDI, storage, and VMs.
- [ ] KubeVirt is `Available` and exposes KVM on `blizzard`.
- [ ] CDI is `Available`.
- [ ] Sealed Secrets is ready and the private key is backed up encrypted.
- [ ] Traefik and cloudflared are ready, but public routes are not switched until security parity is verified.

### Phase 2 — Create reusable VM pattern

- [ ] Standard Debian cloud-image `VirtualMachine` manifest.
- [ ] Boot disk `DataVolume` template.
- [ ] Per-VM data PVC template.
- [ ] cloud-init Secret/SealedSecret template.
- [ ] in-guest baseline: root locked, key-only SSH, qemu-guest-agent, AppArmor, UFW/nftables default deny, unattended upgrades.
- [ ] Service and NetworkPolicy template.
- [ ] Traefik route template with middleware parity from the old NixOS Traefik config.

### Phase 3 — Pilot migrations

Use disabled or low-risk VMs first.

Suggested first candidates:

1. `actual` or `lidarr` if their current disabled state is acceptable.
2. `tautulli` or `overseerr` to prove public ingress and middleware.
3. A split-out `flaresolverr` VM only if you first decide to extract it from the current `prowlarr` MicroVM.

A pilot is complete only when the service survives a VM reboot, Flux reconciliation, and a `blizzard` reboot with rollback still available.

### Phase 4 — Service waves

| Wave | VMs | Goal |
|---|---|---|
| Low-risk | `actual`, `lidarr`, `brave`, `tautulli`, `ombi`, `overseerr` | Prove template, storage, ingress, rollback |
| Media stack | `prowlarr`, `sonarr`, `radarr`, `bazarr`, `readarr`, `lidarr`, `qbittorrent`, `sabnzbd` | Prove shared media access and privacy routing |
| Public data | `gitea`, `matrix-synapse`, `firefly`, `firefly-importer`, `paperless`, `immich`, `mealie`, `searx` | Preserve data integrity, app secrets, and public security controls |
| Network-sensitive | `wireguard`, `adguard` | Preserve raw UDP/DNS behavior with explicit exposure decisions |
| Browser isolation | `firefox`, `brave` | Preserve isolation and VPN routing behavior |

### Phase 5 — Cleanup

- [ ] Disable MicroVM autostart after all KubeVirt VMs are accepted.
- [ ] Keep old state read-only for one backup cycle.
- [ ] Remove `sys.virtualisation.microvm` host config.
- [ ] Remove the `microvm` flake input and host module from `flake.nix`.
- [ ] Remove `vms/` or move selected historical notes to `docs/legacy-microvms.md`.
- [ ] Remove `10.100.0.0/24` from advertised routes if no longer used.
- [ ] Update architecture docs and CI assumptions.

## Per-VM cutover checklist

1. Confirm the old MicroVM is healthy before migration.
2. Snapshot the relevant `flash`/state dataset.
3. Stop the MicroVM.
4. Mount old state image(s) read-only.
5. Boot the KubeVirt VM without public ingress.
6. Copy data into the new data disk.
7. Run service-specific integrity checks.
8. Enable the internal Kubernetes Service.
9. Enable Traefik route through cloudflared.
10. Validate from LAN/Tailscale and from the public route.
11. Keep MicroVM disabled but available for rollback.
12. Mark accepted after reboot/reconcile/backup validation.

## Rollback rule

Rollback remains available until the old MicroVM images are deleted. To roll back a service:

1. Disable the KubeVirt public route.
2. Stop the KubeVirt VM.
3. Start the old MicroVM unit.
4. Restore the old Traefik/cloudflared route if needed.
5. Validate the public route and logs.

## Validation gates

| Gate | Required evidence |
|---|---|
| Cluster | Node `Ready`, Cilium running, pod-to-API ClusterIP smoke test passes, Flux reconciles |
| Operators | KubeVirt Available, CDI Available, Sealed Secrets key backed up |
| Security | Cloudflare Tunnel in front, Traefik headers, CrowdSec bouncer, default-deny NetworkPolicies, VM firewall, no password/root SSH |
| Data | File/database integrity checks and data persistence after reboot |
| Operations | qemu-guest-agent ready, logs available, backup path documented |
| Cleanup | No stale MicroVM references except intentional legacy docs |

## `homelab-apps` implementation status

`telometto/homelab-apps` is now imported and contains the first executable migration resources:

- dependency-ordered Flux Kustomizations
- Kustomize entrypoints for operator/config directories
- `kubevirt-local` and `kubevirt-local-immediate` single-node local storage classes
- removed `runtimeclass-gvisor.yaml`
- `vms/actual` as a manual-control Debian/KubeVirt pilot VM

Still pending in `homelab-apps`:

- Traefik middleware/routes for public cutover
- cloudflared secret handling as SealedSecret
- tighter per-VM NetworkPolicy allowlists
- additional per-VM manifests after the `actual` pilot is accepted
