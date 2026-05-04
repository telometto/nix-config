# MicroVMs → KubeVirt Migration Design

**Date:** 2026-05-04
**Branch:** dev-kubevirt
**Status:** Approved, pending implementation plan

---

## Context

`blizzard` currently runs 23+ NixOS MicroVMs via `microvm.nix` with `cloud-hypervisor` as the
hypervisor. Each VM is a full NixOS configuration built from the flake, using virtiofs to share
`/nix/store` with the host and TAP interfaces on a `10.100.0.0/24` bridge.

Goals driving the migration:

- Live migration of running VMs between nodes
- Kubernetes-native management (`kubectl`, Flux, Helm) for VMs and containers alike
- Multi-node scheduling (single node today, growth path to multiple nodes)
- YAML-based workload definitions in a separate GitOps repo
- Security-first: internet-facing services must be strongly isolated

---

## Chosen Approach: Tiered KubeVirt + gVisor (Approach B)

Services are split into three tiers based on isolation requirements:

| Tier | Mechanism | Isolation level |
|---|---|---|
| VM | KubeVirt `VirtualMachine` (QEMU/KVM) | Full VM — separate kernel |
| Container (gVisor) | k3s pod, `RuntimeClass: gvisor` | User-space kernel sandbox |
| Container (standard) | k3s pod, default runtime | Standard Linux namespaces + hardening |

---

## Architecture

### Infrastructure layer — nix-config repo (stays NixOS)

`blizzard` runs NixOS. `sys.services.k3s.enable = true` brings up k3s in single-server mode.
The `microvm.nix` host module, bridge networking, and TAP interfaces are removed once migration
completes.

The following become k3s workloads (Deployments/Helm charts) rather than NixOS services:
- Traefik reverse proxy
- Cloudflare tunnel (`cloudflared`)

Host-level NixOS services (sops-nix secrets for blizzard itself, Tailscale, resolved, etc.) are
unchanged.

**NixOS-specific requirements for Cilium (discovered during execution):**

The following must be set in `hosts/blizzard/blizzard.nix` for Cilium pod networking to function
on NixOS. Without these, pods have zero network connectivity despite Cilium appearing healthy:

```nix
networking.firewall.checkReversePath = false;   # strict rp_filter drops pod traffic
networking.firewall.trustedInterfaces = [ "lxc+" ]; # Cilium names its veth interfaces lxcXXXXXXXX
```

The k3s module must also include `--disable-kube-proxy` in `extraFlags` to prevent k3s's built-in
iptables kube-proxy from conflicting with Cilium's eBPF service routing (causes ClusterIP timeouts
even when pod-to-internet works). Cilium must use `kubeProxyReplacement: true` — setting it to
`false` does not work with k3s because there is no standalone kube-proxy process to fall back to.

Cilium must be installed directly via Helm **before** bootstrapping Flux. Installing it through
Flux means Flux's own pods can't reach the Kubernetes API server (Cilium's service maps aren't
ready yet), causing a chicken-and-egg deadlock.

### Workload layer — homelab-apps repo (new)

All VM manifests, Deployments, Services, NetworkPolicies, PVCs, and IngressRoutes live in a
separate `homelab-apps` git repo. Flux reconciles it to the cluster.

### Cluster operators

| Operator | Purpose |
|---|---|
| KubeVirt | Run VMs (QEMU/KVM backend) |
| CDI (Containerized Data Importer) | Import and manage VM boot disk images as PVCs |
| Cilium | CNI with NetworkPolicy enforcement and Hubble observability |
| MetalLB (L2 mode) | LoadBalancer for wireguard raw UDP port exposure |
| Traefik | Ingress for VMs and containers |
| Flux | GitOps sync from homelab-apps repo |
| Sealed Secrets | Encrypted secret management |
| gVisor (`runsc`) | User-space kernel sandbox for container tier |

---

## VM Tier

### Services

| VM | vCPU | RAM | Reason for VM tier |
|---|---|---|---|
| `gitea` | 2 | 2 GB | Public git hosting, handles SSH keys and credentials |
| `matrix-synapse` | 4 | 4 GB | Public-facing, handles E2E encryption keys and user data |
| `immich` | 4 | 8 GB | Photo hosting, public-facing |
| `firefly` | 2 | 2 GB | Finance data, public-facing |
| `firefly-importer` | 1 | 512 MB | Finance data, public-facing |
| `paperless` | 4 | 8 GB | Document store, public-facing |
| `wireguard` | 1 | 512 MB | VPN gateway, direct internet exposure, raw UDP |
| `firefox` | 4 | 4 GB | Browser isolation — VM containment is the feature |
| `brave` | 4 | 4 GB | Browser isolation — VM containment is the feature |

### Guest OS

Debian Stable cloud image (imported via CDI `DataVolume` on first boot).

Rationale: minimal default footprint, AppArmor enabled by default, long support cycles,
well-documented KubeVirt integration.

### Storage

Each VM has two PVCs:

1. **Boot disk** — `DataVolume` importing the Debian cloud image. CDI handles the import; subsequent
   boots use the local PVC copy.

2. **Data disk** — `hostPath` PersistentVolume pointing at the existing
   `/flash/enc/vms/<vmname>/` directory on blizzard. Zero data migration on cutover.

### cloud-init security baseline

Applied to every VM via a Kubernetes Secret referenced as `cloudInitNoCloud.userDataSecretRef`:

- Root account locked, `PermitRootLogin no`
- SSH: key-only auth, password auth disabled, `MaxAuthTries 3`
- SSH access restricted to Tailscale interface only (not exposed to internet)
- UFW: default deny inbound, explicit allow for service port only
- AppArmor enabled and enforcing
- Automatic unattended security upgrades enabled

### KubeVirt security context

The `virt-launcher` pod (wraps each VM) runs with:
- `allowPrivilegeEscalation: false`
- No host network namespace
- No host PID namespace

### Networking

VMs use KubeVirt **masquerade** binding (NAT through the pod network). The existing
`10.100.0.x` bridge IPs and TAP interfaces are replaced entirely — VMs are reached inside the
cluster via Kubernetes Services and DNS (`gitea.vms.svc.cluster.local`).

Masquerade is required for live migration compatibility: when a VM moves nodes, its Service IP
follows without network reconfiguration.

**wireguard exception:** Gets a MetalLB `LoadBalancer` Service with a dedicated LAN IP so it can
receive raw UDP/51820 from the internet without NodePort remapping.

### Resource declaration

Hard memory limits matching current vm-registry values (no overcommit). CPU shared by default;
`dedicatedCpuPlacement: true` available per-VM if needed.

---

## Container Tier

### Services

**gVisor sandboxed** (`RuntimeClass: gvisor`) — shared-kernel risk eliminated:

| Service | Image | Notes |
|---|---|---|
| `sonarr`, `radarr`, `prowlarr`, `bazarr`, `readarr`, `lidarr` | `lscr.io/linuxserver/*` | Standard arr stack |
| `qbittorrent` | `lscr.io/linuxserver/qbittorrent` + Gluetun sidecar | VPN routing via sidecar |
| `sabnzbd` | `lscr.io/linuxserver/sabnzbd` + Gluetun sidecar | VPN routing via sidecar |
| `overseerr`, `ombi` | `lscr.io/linuxserver/*` / official | Public-facing request UIs |
| `searx` | `searxng/searxng` | Public-facing, non-root image |
| `mealie`, `actual` | Official images | Non-root natively |

**Standard runtime** (internal-only, no direct internet path):

| Service | Image |
|---|---|
| `tautulli` | `lscr.io/linuxserver/tautulli` |
| `flaresolverr` | `ghcr.io/flaresolverr/flaresolverr` |

### VPN routing — replacing the wireguard VM gateway

`qbittorrent` and `sabnzbd` currently route outbound traffic through the wireguard VM
(`10.100.0.11` gateway). In the container tier this becomes a **Gluetun sidecar** in the same pod.
Gluetun shares the pod's network namespace, so all container traffic exits through the WireGuard
tunnel. Keys and endpoint carry over from the existing wireguard config.

Gluetun requires `CAP_NET_ADMIN` — the only elevated capability anywhere in the container tier,
scoped to those two pods only.

The wireguard KubeVirt VM remains for **inbound VPN** (Tailscale route advertisement) but its
outbound-routing role for containers is removed.

### Security context baseline

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true  # where image supports it
```

`linuxserver.io` images start as root internally then drop to `PUID`/`PGID` — `runAsNonRoot: true`
breaks them. Mitigation: `allowPrivilegeEscalation: false` + all caps dropped + NetworkPolicies.
For natively non-root images (`searx`, `mealie`, `actual`): add `runAsNonRoot: true`.

### Storage

- **Media library:** single `hostPath` PV pointing at blizzard's existing media mount. All arr
  services share it. `hostPath` is `ReadWriteOnce` per Kubernetes semantics but works fine for
  multi-pod access on a single node. When a second node is added, this must be replaced with an
  NFS-backed PV or a distributed storage solution (e.g. Longhorn, Ceph).
- **Config/state:** per-service `hostPath` PVC. The *arr services are currently MicroVMs, so their
  state (e.g. `/var/lib/sonarr`) is inside the VM's `persist.img` block image — not directly
  accessible as a host path. Cutover procedure for each: stop MicroVM → mount `persist.img` via
  loop device → copy service state to a new host directory → point container PVC at that directory.

### Namespaces and Pod Security Standards

| Namespace | Contents | Pod Security Standard |
|---|---|---|
| `vms` | KubeVirt VMs | Baseline (virt-launcher requirement) |
| `media` | arr stack, download clients | Baseline (linuxserver.io root-start) |
| `apps` | searx, mealie, actual, overseerr, ombi | Restricted (non-root or hardened) |
| `internal` | tautulli, flaresolverr | Baseline |
| `ingress` | Traefik, cloudflared | Privileged (Traefik needs host port binding) |

All namespaces: hard resource `requests` and `limits` on every workload.

---

## Networking

### CNI: Cilium

k3s's default Flannel is replaced with Cilium. Reasons:

- Full Kubernetes NetworkPolicy enforcement (Flannel has none)
- Hubble: real-time network observability UI (see exactly what traffic is allowed/denied)
- eBPF-based, low overhead

### Traffic flow

```
Internet
  └─ Cloudflare Tunnel (cloudflared Deployment, `ingress` namespace)
       └─ Traefik (Deployment, IngressRoute CRDs)
            └─ Service → VM pod (vms) or container pod (media/apps/internal)

LAN
  └─ Traefik NodePort / Tailscale
       └─ Service → VM or container

wireguard inbound
  └─ MetalLB VIP → wireguard VM Service (UDP 51820)
```

### NetworkPolicies (Cilium)

Default-deny ingress and egress on all namespaces. Explicit allows:

| Rule | Direction |
|---|---|
| All pods → CoreDNS (UDP/TCP 53) | Egress |
| All pods → internet (TCP 443/80) | Egress (tightened per-service where possible) |
| Traefik → pods in vms/media/apps/internal | Ingress |
| Pods within `media` namespace | Ingress (arr inter-service communication) |
| `qbittorrent`/`sabnzbd` → internet directly | Egress DENY (only Gluetun VPN endpoint allowed) |
| `wireguard` VM ← internet (UDP 51820) | Ingress |
| `wireguard` VM → LAN CIDR | Egress |

---

## Secrets Management

### Sealed Secrets

The Sealed Secrets controller runs in the cluster. Secrets are stored as `SealedSecret` YAML
files in the `homelab-apps` repo — asymmetrically encrypted, safe to commit to git.

Key properties:
- **Namespace-bound**: a `SealedSecret` created for the `vms` namespace cannot be decrypted in
  `media` or any other namespace, even if the YAML is copied
- **No SOPS/age key derivation** from SSH host keys — no sops-nix involvement for workload secrets
- One-time bootstrap: back up the Sealed Secrets controller private key after cluster init

Workflow: `kubeseal < secret.yaml > sealed-secret.yaml`, commit to `homelab-apps`.

### VM secrets via cloud-init

Each VM's `VirtualMachine` manifest references a Secret containing cloud-init `user-data`
(SSH keys, service credentials, firewall config). That Secret is a `SealedSecret` in git.

### blizzard host secrets

Unchanged — blizzard remains NixOS, sops-nix continues to manage host-level secrets. Only
per-VM age keys (derived from MicroVM SSH host keys) are superseded.

---

## GitOps — homelab-apps repo

Flux reconciles the repo. Each subdirectory is an independent Flux `Kustomization` so a broken
manifest in one service does not block others.

```
homelab-apps/
  flux/              # Flux bootstrap manifests
  namespaces/        # Namespace + PodSecurity definitions
  storage/           # PVs, PVCs, StorageClasses
  network/           # NetworkPolicies, MetalLB config, Cilium config
  vms/               # KubeVirt VirtualMachine YAMLs
    gitea/
    matrix-synapse/
    immich/
    firefly/
    firefly-importer/
    paperless/
    wireguard/
    firefox/
    brave/
  apps/
    media/           # arr stack, qbittorrent, sabnzbd Deployments
    web/             # searx, mealie, actual, overseerr, ombi Deployments
    internal/        # tautulli, flaresolverr Deployments
  ingress/           # Traefik IngressRoutes, Middleware CRDs, cloudflared Deployment
  secrets/           # SealedSecret YAMLs (encrypted, safe to commit)
```

---

## Migration Plan

Downtime per service is acceptable. Hard cutover (no parallel running).

### Phase 1 — Cluster bootstrap (no workload changes)

1. Enable k3s on blizzard: `sys.services.k3s.enable = true`
2. Deploy Cilium CNI (replace Flannel)
3. Install operators: KubeVirt, CDI, MetalLB, Sealed Secrets controller, gVisor node config
4. Deploy Traefik as a k3s Deployment and disable the NixOS Traefik and cloudflared services in
   nix-config simultaneously; run `nixos-rebuild boot` (not `switch`) so the changeover takes
   effect on the next reboot — k3s Traefik owns 80/443 from first boot, no overlap window
5. Deploy Flux; point at `homelab-apps` repo
6. Back up Sealed Secrets controller private key

MicroVMs keep running throughout Phase 1.

### Phase 2 — Container services

Migrate in any order (stateless, low risk):

- `tautulli`, `flaresolverr` (standard runtime, internal-only — lowest risk)
- `sonarr`, `radarr`, `prowlarr`, `bazarr`, `readarr`, `lidarr` (gVisor, LAN-only)
- `qbittorrent`, `sabnzbd` (gVisor + Gluetun sidecar; validate VPN tunnel before enabling)
- `overseerr`, `ombi`, `searx`, `mealie`, `actual` (gVisor)

Disable corresponding MicroVM after each service validates.

### Phase 3 — Medium VMs

- `firefly` + `firefly-importer`
- `paperless`

For each: shut down MicroVM → create KubeVirt VM pointing data PVC at existing
`/flash/enc/vms/<name>/` path → boot → validate → done.

### Phase 4 — Network-sensitive VMs

- `wireguard` — brief VPN outage (~2 min); configure MetalLB VIP first, then cut over

### Phase 5 — High-stakes VMs

- `gitea` — brief git hosting outage; validate SSH and HTTP before and after
- `matrix-synapse` — brief Matrix outage; validate federation and E2E keys
- `immich` — validate photo library integrity post-cutover
- `firefox`, `brave` — stateless, cut over freely

### Phase 6 — Cleanup

- Disable `sys.virtualisation.microvm` in nix-config
- Remove `microvm` flake input from `flake.nix`
- Remove `vms/` directory from nix-config
- Disable NixOS Traefik and cloudflared services (replaced by k3s Deployments)
- Remove `hosts/blizzard/virtualisation/microvms.nix`

---

## Pros & Cons Summary

### Current MicroVMs (microvm.nix + cloud-hypervisor)

| Pros | Cons |
|---|---|
| Tight Nix integration — VMs are NixOS configs, `nixos-rebuild switch` works | No live migration |
| virtiofs `/nix/store` sharing — no duplicated packages per VM | Single-node only, no scheduler |
| Fast boot — cloud-hypervisor (Rust-based, minimal attack surface) | VM definitions coupled to nix-config repo |
| Zero Kubernetes dependency | Manual TAP/bridge/NAT wiring per VM |
| Proven, running today | No standard tooling (kubectl, Helm, Flux) |

### KubeVirt on k3s (this design)

| Pros | Cons |
|---|---|
| Live migration (masquerade networking) | cloud-hypervisor not supported — QEMU/KVM only (larger attack surface, slower boot than cloud-hypervisor) |
| Multi-node scheduling — add a node, workloads spread automatically | k3s + KubeVirt baseline overhead ~1.5–2 GB RAM before any workloads |
| YAML in a separate repo, full GitOps with Flux | VMs carry full OS disk images (~2 GB each) — no virtiofs store sharing |
| Same tooling for VMs and containers (`kubectl`) | More moving parts (CDI, MetalLB, Cilium, Sealed Secrets, Traefik as Deployment) |
| Cilium NetworkPolicies for real east-west isolation | Per-VM sops-nix workflow fully replaced — some migration effort |
| gVisor eliminates shared-kernel risk for container tier | One-time manual step: back up Sealed Secrets controller key |
| Sealed Secrets — no age/SSH-key bootstrap headache | Loss of `nixos-rebuild switch` inside VMs |
| Standard cloud images — no NixOS expertise needed inside VMs | Guest OS updates managed separately (unattended-upgrades) rather than via nix |
