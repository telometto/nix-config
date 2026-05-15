# MicroVMs → KubeVirt Migration Design

Status: accepted design for the `dev-kubevirt` branch.

This document describes the target architecture for migrating the existing `blizzard` MicroVM fleet to KubeVirt. It intentionally supersedes the earlier tiered VM/container design: every current MicroVM workload remains VM-isolated and becomes a KubeVirt `VirtualMachine`.

## Summary

`blizzard` keeps ownership of the host operating system through this `nix-config` flake. k3s runs on the host, Cilium provides CNI and kube-proxy replacement, and Flux reconciles Kubernetes workloads from `telometto/homelab-apps`. KubeVirt and CDI provide VM lifecycle and image import. Debian Stable cloud images are used as guest images for the migrated workloads.

Public ingress remains Cloudflare Tunnel → Traefik → Kubernetes Service → KubeVirt VM. No internet-facing service is exposed directly from a VM or NodePort unless it is an explicitly reviewed raw protocol such as WireGuard UDP.

## Goals

- Replace all current MicroVM workloads with KubeVirt VMs.
- Keep the VM isolation boundary for internet-facing and sensitive services.
- Use GitOps for Kubernetes operators, networking, ingress, secrets, storage, and VM manifests.
- Preserve the current security posture: Cloudflare Tunnel, Traefik security middleware, CrowdSec/bouncer, default-deny NetworkPolicies, hardened guests, and VPN kill switches.
- Start with single-node local PV/hostPath storage on `blizzard` to avoid expanding scope before the first working migration.
- Keep MicroVM rollback available until each service is accepted.

## Non-goals

- Replacing VM isolation with shared-kernel Kubernetes containers.
- Reintroducing gVisor during this migration.
- Claiming real live migration while using single-node local storage.
- Removing MicroVM support before all services are migrated and validated.

## Chosen approach

| Layer | Technology | Responsibility |
|---|---|---|
| Host OS | NixOS from this flake | k3s service, firewall, bootstrap, secrets integration |
| CNI | Cilium | Pod networking, kube-proxy replacement, NetworkPolicy, observability |
| GitOps | Flux | Reconcile `telometto/homelab-apps` |
| VM orchestration | KubeVirt | VM lifecycle, virt-launcher pods, guest console/API |
| Image import | CDI | Debian Stable cloud image and data volume import |
| Guest OS | Debian Stable cloud image | Application runtime inside each VM |
| Ingress | cloudflared (k3s Deployment via Flux) + Traefik | Public route termination and security middleware; cloudflared runs in k3s, not as a NixOS host service |
| Secrets | sops-nix + Sealed Secrets | Host/bootstrap secrets and workload secrets |
| Storage phase 1 | local PV/hostPath PVCs | Single-node persistent VM disks on `blizzard` |

## Repository split

| Repo | Contents |
|---|---|
| `telometto/nix-config` | Host-level NixOS modules, k3s/Cilium/Flux bootstrap, legacy MicroVM inventory during migration |
| `telometto/homelab-apps` | Flux Kustomizations, KubeVirt/CDI/SealedSecrets/Traefik manifests, storage, NetworkPolicies, VM manifests |
| `telometto/nix-secrets` | Private host secrets consumed by sops-nix |

`homelab-apps` is imported alongside this repo and contains bootstrap manifests for Flux, Cilium, KubeVirt, CDI, sealed-secrets, ingress, namespaces, default-deny policies, local storage, and the first manual-control KubeVirt pilot VM. The old gVisor RuntimeClass has been removed from the active GitOps path.

## Bootstrap design

The bootstrap sequence must avoid the original Cilium/Flux deadlock:

1. k3s starts with flannel disabled, kube-proxy disabled, and k3s network policy disabled.
1. The NixOS bootstrap service installs Cilium first.
1. The bootstrap service waits for the Cilium DaemonSet and verifies pod-to-API ClusterIP connectivity.
1. Flux operator and flux-instance are installed only after Cilium networking works.
1. Flux reconciles `homelab-apps/flux`.
1. Flux manages long-lived Kubernetes resources from that point onward.

Canonical Cilium settings:

| Setting | Value |
|---|---|
| k3s flag | `--disable-kube-proxy` |
| k3s flag | `--flannel-backend=none` |
| k3s flag | `--disable-network-policy` |
| Cilium | `kubeProxyReplacement: true` |
| Cilium | `k8sServiceHost: "127.0.0.1"` |
| Cilium | `k8sServicePort: 6443` |
| Cilium | `routingMode: native` |
| Cilium | `ipv4NativeRoutingCIDR: "10.42.0.0/16"` |
| Cilium | `autoDirectNodeRoutes: true` |
| NixOS firewall | `checkReversePath = false` |
| NixOS firewall | `interfaces."lxc+".allowedTCPPorts = [ 6443 4240 4244 4245 ]` |

Do not trust all `lxc+` pod veth traffic on the host firewall. Keep pod-to-host
access scoped to the k3s API backend and Cilium/Hubble internals required by the
bootstrap smoke test and observability stack.

`kubeProxyReplacement: false` is not an acceptable fallback in this k3s setup because no standalone kube-proxy is running.

## VM blueprint

Each migrated service gets a KubeVirt VM with:

- Debian Stable cloud image boot disk imported by CDI.
- one or more persistent data disks.
- cloud-init from a SealedSecret.
- qemu-guest-agent.
- root account locked.
- key-only SSH.
- AppArmor and unattended security updates.
- in-guest firewall default deny.
- a Kubernetes Service for the workload port.
- a minimal NetworkPolicy allowlist.
- a Traefik route only if the service is public.

Application deployment inside the guest can stay close to the current service shape. Running Podman or Docker inside the guest is acceptable during migration when it reduces risk; the isolation boundary is still the VM.

## Network and ingress

Default public path:

```text
Cloudflare Tunnel -> Traefik -> Kubernetes Service -> virt-launcher pod -> VM service
```

Rules:

- Do not expose HTTP services through public NodePorts.
- Preserve Traefik security headers and CrowdSec/bouncer behavior before switching public routes.
- Use NetworkPolicies to default-deny workload namespaces and explicitly allow ingress from Traefik.
- Keep DNS, update, app-dependency, and VPN egress explicit.
- Raw UDP services such as WireGuard require a specific exposure design, likely MetalLB or a tightly controlled host/network binding.

## Storage

Phase 1 uses local storage on `blizzard`:

| Path | Purpose |
|---|---|
| `/flash/enc/vms` | Current MicroVM state, kept for rollback |
| `/flash/enc/kubevirt` | New KubeVirt VM disks/PVs |

This is deliberately simple and single-node. It does not satisfy real live migration semantics. Future storage work can introduce distributed storage or a shared backend after the VM migration is proven.

## Secrets

- Host/bootstrap secrets remain in `nix-secrets` and are exposed through sops-nix.
- Workload Kubernetes secrets should be committed to `homelab-apps` only as SealedSecrets.
- Back up the Sealed Secrets controller private key before migrating important workload secrets.
- Do not commit private keys, decrypted secrets, `.sops.yaml`, or generated secret manifests.

## Security invariants

The migration is not allowed to weaken these controls:

- VM boundary for current MicroVM services.
- Cloudflare Tunnel in front of internet-facing HTTP services.
- Traefik middleware parity with the old NixOS Traefik behavior.
- CrowdSec/bouncer on public routes where it exists today.
- default-deny Kubernetes NetworkPolicies.
- in-guest firewall and SSH hardening.
- VPN-only egress or kill switch for privacy-routed workloads.
- rollback path for every service until data and public exposure are validated.

## Migration waves

| Wave | VMs | Purpose |
|---|---|---|
| Pilot | `actual`, `lidarr` | Prove image import, storage, VM template, rollback |
| Ingress pilot | `tautulli`, `ombi`, `overseerr`, `searx` | Prove public route and middleware parity |
| Media stack | `prowlarr`, `sonarr`, `radarr`, `bazarr`, `readarr`, `qbittorrent`, `sabnzbd` | Prove media storage and VPN routing |
| Sensitive public data | `gitea`, `matrix-synapse`, `firefly`, `firefly-importer`, `paperless`, `immich`, `mealie` | Preserve state, secrets, and public security controls |
| Network services | `wireguard`, `adguard` | Preserve raw UDP/DNS semantics with explicit exposure decisions |
| Browser isolation | `firefox`, `brave` | Preserve browser isolation and privacy routing |

The exact order can change if operational risk changes, but do not start with `gitea`, `matrix-synapse`, `immich`, `paperless`, `wireguard`, or `adguard`.

## Cutover flow

For each VM:

1. Verify the old MicroVM is healthy.
1. Snapshot old state.
1. Stop the old MicroVM.
1. Mount old state read-only.
1. Boot the KubeVirt VM without public ingress.
1. Copy and validate data.
1. Enable internal Kubernetes Service and NetworkPolicy.
1. Enable public Traefik/cloudflared route when applicable.
1. Validate externally.
1. Keep rollback available until reboot, reconcile, and backup validation pass.

## Cleanup design

Only after every VM is accepted:

1. Disable MicroVM autostart.
1. Keep old state read-only for one backup cycle.
1. Remove `sys.virtualisation.microvm` from `blizzard`.
1. Remove the `microvm` flake input and module wiring.
1. Remove or archive `vms/`.
1. Remove `10.100.0.0/24` route advertisement if unused.
1. Update architecture and CI docs.

## Related docs

- `docs/kubevirt-migration-plan.md` — execution tracker and inventory.
- `docs/kubevirt-operations.md` — day-2 operations runbook.
- `docs/superpowers/plans/2026-05-04-kubevirt-bootstrap.md` — bootstrap implementation plan.
