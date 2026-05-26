# KubeVirt Production Migration Notes

Notes captured on 2026-05-17 while reviewing the current MicroVM-to-KubeVirt
migration state across `telometto/nix-config` and `telometto/homelab-apps`.
These are planning notes for the real production migration after the `actual`
pilot.

## Current state

- `homelab-apps/vms/actual` is a pilot, not a production-ready VM pattern.
- The pilot proves KubeVirt/CDI image import, static local PV binding, manual
  VM lifecycle, `qemu-guest-agent`, and internal Service reachability.
- Only `actual` is currently an executable KubeVirt VM in `homelab-apps/vms`.
  The rest of the fleet is still represented only by inventory metadata and the
  legacy MicroVM definitions in `nix-config/vms`.
- Phase 1 storage is intentionally single-node local storage on `blizzard`.
  This is acceptable for initial migration work but is not live-migration-ready.

## Production gaps before real cutover

- Add per-VM KubeVirt manifests beyond `actual`.
- Split durable app data from the replaceable root disk. Production VMs should
  use a Debian cloud-image root disk plus one or more dedicated data disks/PVCs.
- Add host-side storage paths for each migrated VM under
  `/flash/enc/vms/kubevirt/<vm>/...`.
- Pin guest images and application/container versions. Avoid `latest` for
  accepted production VMs.
- Replace plain Kubernetes Secrets with SealedSecrets or another encrypted
  GitOps secret workflow before committing real secrets.
- Preserve Traefik/cloudflared/CrowdSec/security-header parity before enabling
  public routes.
- Tighten the current pilot-style namespace-wide egress policy into per-VM and
  per-importer policies.
- Decide `/data` shared storage before migrating the media stack.
- Decide VPN/raw-protocol networking before migrating `qbittorrent`, `sabnzbd`,
  browser VMs, `wireguard`, or `adguard`.
- Validate every accepted VM through reboot, Flux reconciliation, backup, and
  rollback tests.

## Data migration model

Prefer file-level or logical migration from old MicroVM state to new KubeVirt
data disks. Do not treat old NixOS MicroVM root/state images as the new guest OS.

Per VM:

1. Verify the old MicroVM is healthy.
1. Snapshot the relevant ZFS dataset or storage root.
1. Stop the old MicroVM cleanly.
1. Mount old state images read-only.
1. Boot the KubeVirt VM without public ingress.
1. Copy app state into the new VM data disk.
1. Fix ownership and permissions in the guest.
1. Use logical dump/restore for PostgreSQL-backed apps unless identical major
   versions and clean block-level state are deliberately verified.
1. Run service-specific integrity checks.
1. Enable internal Service validation.
1. Enable public ingress only after security parity and rollback are proven.
1. Keep old MicroVM data read-only for at least one successful backup cycle.

Important state classes:

- Media apps need app state plus shared `/data` compatibility.
- PostgreSQL-backed apps need database dumps/restores and app-secret parity.
- Matrix/Gitea/Firefly/Paperless/Immich/AdGuard need secret-aware migration;
  copying files alone is not enough.
- VPN-routed apps need leak tests before acceptance.

## Cloud-init template guidance

The large `vms/actual/cloudinit-secret.yaml` payload should not be copied
wholesale to every VM. It contains both useful baseline logic and Actual-specific
application setup.

Reusable baseline pieces:

- lock root and disable password SSH;
- create key-only admin access;
- clamp guest MTU if the Cilium/KubeVirt path still requires it;
- use explicit Debian sources and short apt timeouts;
- install and start `qemu-guest-agent`;
- install `nftables` when Podman/netavark is used;
- configure UFW/nftables default-deny;
- allow only required service/admin ports;
- configure journald/log rotation, AppArmor, and unattended security updates;
- create a bootstrap completion marker.

Per-VM pieces that must be rewritten:

- systemd unit names;
- service/container image and pinned version;
- app data path;
- app port and any container bridge port;
- app-specific firewall forward rules;
- app-specific secrets and environment.

## VPN routing options

### VPN client and kill switch inside each VM

Best first production choice for privacy-sensitive workloads.

Pros:

- Strong per-VM isolation.
- Works with the current simple KubeVirt masquerade model.
- Failure is contained to one VM.
- In-guest kill switch can be strict and easy to validate.
- Kubernetes/Cilium NetworkPolicy can add a second guardrail.

Cons:

- Duplicates VPN configuration and firewall logic across VMs.
- More credentials and endpoints to rotate.
- Each VM needs independent leak testing.
- Multiple VPN sessions may be less efficient or conflict with provider limits.

### Dedicated KubeVirt VPN gateway VM plus secondary networking

Closest match to the old MicroVM gateway model.

Pros:

- Centralizes VPN config and kill-switch behavior.
- Preserves the old mental model where selected workloads route through one
  gateway.
- More efficient than one tunnel per VM.
- Easier credential rotation.

Cons:

- Needs a real secondary network/routing design; current masquerade networking
  does not recreate the old `10.100.0.11` gateway semantics by itself.
- Gateway becomes a single point of failure.
- Misrouting can leak multiple workloads at once.
- Harder to validate and express cleanly in GitOps.

### Multus, bridge, or macvtap networking

Most VM-like network model; useful for services that need LAN-like semantics.

Pros:

- Can provide predictable VM addressing and gateway routing.
- Useful for raw protocols, DNS, WireGuard, and gateway designs.
- Makes some NAT-sensitive services simpler.

Cons:

- Highest operational complexity.
- May bypass normal Kubernetes NetworkPolicy depending on attachment type.
- More host/LAN blast radius.
- Harder scheduling and future live-migration story when interfaces are
  node-specific.
- Debugging spans Kubernetes, Cilium, Multus, Linux bridges/macvtap, guest
  firewalls, and physical networking.

### Kubernetes-network egress policy design

Useful as a guardrail, not a complete VPN design.

Pros:

- GitOps-native and declarative.
- Good baseline for all VMs.
- Works well for normal HTTP services and app dependency allowlists.
- Pairs well with per-VM VPN clients by allowing only VPN endpoint egress.

Cons:

- NetworkPolicy does not route traffic through a VPN by itself.
- KubeVirt masquerade traffic is evaluated as `virt-launcher` pod traffic,
  which can be subtle.
- Policy mistakes can permit direct egress unless leak-tested.
- Bootstrap flows may temporarily need broader egress unless images/packages are
  pre-baked.

Recommended initial approach: use per-VM VPN clients and in-guest kill switches
for `qbittorrent`, `sabnzbd`, `firefox`, and `brave`, with Cilium policies as a
second guardrail. Revisit a centralized VPN gateway only after the basic KubeVirt
VM pattern is accepted.

## Shared `/data` storage for the media stack

Shared PVs/PVCs are possible, but only if the backend supports shared filesystem
semantics. Do not attach the same writable block disk to multiple VMs unless a
cluster-aware filesystem is intentionally used.

Viable patterns:

| Pattern | Notes |
|---|---|
| NFS-backed RWX PVC | Pragmatic first choice for `/rpool/unenc/media/data`; can be represented as static PV/PVC or via NFS CSI. |
| Guest-mounted NFS | Simpler and very explicit, but less Kubernetes-native. |
| CephFS/distributed RWX | Better future multi-node story but higher operational cost. |
| Longhorn RWX | Kubernetes-native convenience with extra moving parts and performance trade-offs. |
| KubeVirt filesystem/virtiofs style attachment | Attractive if fully supported and tested in this environment. |
| Shared writable block PVC | Avoid for normal ext4/xfs-style filesystems. |

Pros of shared `/data`:

- Preserves the old shared media path expected by Arr apps, qBittorrent, and
  SABnzbd.
- Avoids duplicating large media libraries.
- Allows separate backup/lifecycle policy for media versus VM state.
- Can use read-only mounts for consumers that do not need writes.
- Provides a cleaner future migration path to a better RWX backend.

Drawbacks:

- Current `kubevirt-local` storage classes are static local storage, not RWX
  shared storage.
- KubeVirt PVCs attached as disks are not automatically directories in the
  guest; `/data` needs NFS, virtiofs, or another filesystem-sharing mechanism.
- UID/GID and permission drift can break imports and hardlinks.
- Metadata-heavy media operations can expose NFS/RWX performance limits.
- Multiple writers increase the blast radius of compromised VMs or bad app
  behavior.
- `blizzard`-hosted NFS improves sharing but not high availability.

Recommended split:

- root disk: replaceable guest OS;
- app state disk: per-service durable state;
- shared media: separate RWX `/data` backend.

Start with NFS-backed RWX storage for `/data` unless there is a deliberate reason
to take on a distributed storage system now.

## SealedSecrets placement

Store plaintext secret source in the private `nix-secrets`/sops workflow. Store
only deployable encrypted Kubernetes secret objects in `homelab-apps`.

Suggested ownership:

| Secret class | Recommended location |
|---|---|
| Plaintext source values | private `nix-secrets` or password manager |
| Host/bootstrap secrets | `nix-secrets`, consumed through sops-nix |
| SealedSecret manifests | `homelab-apps`, next to the app/infrastructure manifests that use them |
| Sealed Secrets controller private key backup | private `nix-secrets`/sops repo |
| Cloudflared tunnel token | SealedSecret in `homelab-apps`; plaintext source in private secrets store |
| Flux Git SSH key | private `nix-secrets` or manually staged bootstrap Secret |

Important rules:

- Commit SealedSecrets, not plaintext Kubernetes Secrets, for real workload
  secrets.
- Back up the Sealed Secrets controller private key before relying on it.
- Treat SealedSecrets as deployment artifacts, not the only source of truth.
- Remember that normally sealed values are name/namespace scoped; renames require
  resealing.

Alternative: Flux SOPS decryption could align more directly with the existing
sops workflow, but it makes Flux decryption key bootstrap more sensitive. Given
the current migration already installs Sealed Secrets, the pragmatic path is:

1. Keep plaintext source in `nix-secrets`.
1. Generate SealedSecrets for Kubernetes workloads.
1. Commit SealedSecrets to `homelab-apps`.
1. Back up the Sealed Secrets controller private key in `nix-secrets`.

## Recommended next decisions

1. Decide and document `/data` implementation before media VM manifests are
   added.
1. Decide whether VPN workloads start with per-VM VPN clients or a centralized
   gateway design. Prefer per-VM VPN clients for the first production wave.
1. Turn the `actual` pilot into a production-style pattern with a separate data
   disk before migrating accepted data.
1. Add SealedSecret handling for cloudflared and any real cloud-init/app secrets.
1. Add Traefik middleware/IngressRoute parity before exposing a KubeVirt VM
   publicly.
1. Migrate in low-risk waves before touching `gitea`, `matrix-synapse`,
   `paperless`, `immich`, `wireguard`, or `adguard`.