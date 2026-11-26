# Private Actual KubeVirt pilot

This prepares an additive pilot on Blizzard for GitOps and VM management.
Implementation stops before activation. Production MicroVMs, host Traefik,
Cloudflare Tunnel, and their configuration remain in place.

## Ownership and pins

| Owner | Contents |
|---|---|
| `nix-config` | `sys.virtualisation.actualPilot`, k3s host service, initial create-only Flux seed, scoped firewall rules, directories, matching virtctl |
| `homelab-apps/clusters/blizzard-actual-pilot` | Flux desired state, KubeVirt/CDI, storage, Actual VM, Service and policies |

Host k3s is pinned to the `k3s_1_35` attribute from `flake.lock`
(1.35.10+k3s1 at implementation). Flux is 2.10.1, KubeVirt/virtctl 1.9.1,
and CDI 1.66.1. The companion `pins.json` records the exact release-manifest
hashes and immutable Debian 13/Actual 26.11.0 OCI digests. The curated Debian
cloud image is imported from its digest-pinned registry containerdisk;
CDI verifies registry content identity instead of relying on a checksum
annotation for an unverified HTTP download.

The existing `sys.services.k3s.enable = false` disables the old wrapper.
The pilot enables the upstream `services.k3s` service directly, so shared
wrapper defaults and other hosts are unaffected.

## Isolation

| Item | Pilot value |
|---|---|
| Cluster state | `/var/lib/rancher/k3s-actual-pilot` |
| Config | `/etc/k3s-actual-pilot/config.json` |
| Root-owned admin kubeconfig | `/etc/rancher/k3s-actual-pilot/k3s.yaml`, mode 0600 |
| Kubelet root | `/var/lib/kubelet-actual-pilot` |
| New disk directories | `/flash/enc/vms/kubevirt-pilot/actual/{root,data}` |
| Pod / Service CIDR | `10.44.0.0/16` / `10.45.0.0/16` |
| DNS Service | `10.45.0.10` |
| VM / namespace / HTTP port | `actual-pilot` / `actual-pilot` / TCP 5006 |
| Source path | `clusters/blizzard-actual-pilot` on `homelab-apps/main` |

Bundled Flannel, kube-proxy, DNS, and network-policy enforcement stay enabled.
Bundled Traefik, ServiceLB, and dynamic local storage are disabled. There
is no pilot public route, host port, NodePort, or additional ingress controller.
Host firewall exceptions apply only to pod-to-host API/kubelet traffic on
`cni0`; existing host trust and reverse-path settings remain intact. A
dedicated native nftables table also drops external API/kubelet and VXLAN
traffic before Tailscale's broad INPUT allowance. It runs after destination
NAT, covering the API ClusterIP as well as direct host addresses. Its local
destination match preserves unrelated subnet-router forwarding. This guard
must succeed before k3s starts and remains installed if its unit stops.

The pinned KubeVirt CR patches virt-handler mounts/flags for the isolated
kubelet root. Both kubelet and KubeVirt still use the canonical host
`/var/lib/kubelet/device-plugins` directory for plugin registration; that
directory is mounted separately into virt-handler. Recheck those patches
when upgrading KubeVirt.

Upstream k3s still has shared runtime paths, including `/run/k3s` and
`/run/flannel`. First start refuses existing runtime sockets, Flannel/CNI or
device-plugin state, the global node password, or an existing default
`/etc/rancher/k3s/k3s.yaml`. k3s itself replaces that default path with a
symlink even when given a custom output path; the metadata-only guard
prevents replacement of a foreign credential. Later starts accept only the
pilot-owned link. Registry configuration is explicitly empty, and legacy
image credential providers are disabled through separate pilot paths.
No existing credential contents are read by the guard.

Investigate ownership if it refuses; do not remove old state or run generic
k3s kill-all/uninstall scripts. Cluster state isolation does not mean the
host's networking and runtime are completely independent.

## Local checks without private inputs

Run from this repository:

```bash
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/codex/actual-pilot-nix" \
nix-build --no-out-link --expr '
  let lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      nixpkgs = builtins.fetchTree lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
  in import ./tests/actual-pilot-check.nix { inherit nixpkgs; }'
```

This evaluates the opt-in module against public NixOS, runs create-only
bootstrap and metadata safety tests, and checks nftables syntax in an
isolated Linux kernel library. It does not evaluate the private host flake.
The same check is declared as `checks.x86_64-linux.actual-pilot` for normal CI.
Run `nix-build tests/actual-pilot --no-out-link` in the companion repository
for its manifest, schema, release-hash, disk-safety, offline systemd boot
dependency, and CEL-Go health-expression checks. CEL-Go is pinned to the
version used by the bundled Flux kustomize-controller. No check starts a VM
or changes host networking.

## Gates before a separately authorized deployment

1. Review both repository changes and publish the companion tree to the
   source branch before starting host bootstrap. Do not point the pilot at
   the legacy `flux/` tree. Public HTTPS requires no GitHub secret.
1. Full Blizzard evaluation/build requires the private input. This
   implementation's public checks do not establish a successful full host
   build. Do not inspect private secret files to work around that limit.
1. Compare the proposed generation with the actual running generation.
   Inspect `nixos-rebuild dry-activate` output and the unit/runner diff before
   any switch. The main branch contains changes beyond the pilot; a plain
   switch may restart MicroVMs when their runner changes. If production
   MicroVMs would stop/restart, resolve this before deployment. Do not
   disable their restart policy as a shortcut.
1. Recheck all routing tables, including Tailscale policy routes, for CIDR
   overlap; inspect ports 6443/10250 and shared Kubernetes runtime/credential
   ownership. Preserve any old credential files without opening them.
   Confirm `/flash/enc/vms` is mounted and the new disk directories are
   unused. Existing pilot/MicroVM disks must not be reused or deleted.
1. Record production VM IDs/MainPIDs, route/policy state, and representative
   existing service health. Repeat these checks after deployment and pilot
   operations. Existing PID changes or service failures need investigation.
1. Obtain explicit activation authorization. This task intentionally runs
   no switch, live apply, service restart, or reboot.

`gitBranch` controls the initial seed only. For a review-branch deployment,
also change `homelab-apps/.../sync.yaml` to that branch; Flux subsequently
owns the GitRepository spec. Return both to `main` after acceptance.

## Commands for an activated pilot

The commands below are for a later authorized deployment/acceptance session.
Define a helper on Blizzard that selects only the new kubeconfig:

```bash
pilot() { sudo kubectl --kubeconfig=/etc/rancher/k3s-actual-pilot/k3s.yaml "$@"; }
```

Check bootstrap, operators, disks, VM readiness, and the guest agent:

```bash
systemctl status k3s actual-pilot-bootstrap --no-pager
pilot get nodes
pilot -n flux-system get gitrepositories,kustomizations
pilot -n kubevirt get kubevirt
pilot get cdi
pilot -n actual-pilot get dv,pvc,vm,vmi,svc,networkpolicy
sudo actual-pilot-virtctl -n actual-pilot guestosinfo actual-pilot
```

The create-only seed never applies over existing Flux/controller/source
objects. A failed unit can be retried after its cause is corrected; repeating
bootstrap is not a controller-upgrade mechanism. Controller/operator upgrades
belong in Git. Review console bootstrap output if the VM boots but HTTP is
unready:

```bash
sudo actual-pilot-virtctl -n actual-pilot console actual-pilot
```

Guest provisioning uses signed Debian packages over HTTPS, DHCP-provided
MTU/DNS, guest-agent setup, and a systemd-managed pinned Actual container.
Podman uses host networking inside the VM. Actual cannot start before the
identified data disk is mounted. First format requires the expected serial,
size range, no existing signature, and a complete zero-content check.
An existing filesystem is accepted only as labelled pilot ext4.
The filesystem label is `actual-pilot`; the device serial remains
`actual-pilot-data`. Disk preparation and the data mount have an offline
checked boot dependency graph. A cached pinned Actual image can start
without contacting the registry; initial provisioning still needs HTTPS.

### Private browser access

On Blizzard, keep this running:

```bash
sudo actual-pilot-virtctl -n actual-pilot port-forward \
  --address=127.0.0.1 vmi/actual-pilot 15006:5006
```

On the client computer, keep a second terminal running:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:15006:127.0.0.1:15006 blizzard
```

Open `http://127.0.0.1:15006` and use disposable pilot data. The loopback
browser origin also avoids requiring a public HTTPS endpoint for the web
client. A port-forward is a temporary authenticated admin connection; an
in-cluster HTTP probe is a separate NetworkPolicy test.

The forwarder connects through KubeVirt's `virt-api` pods. The Actual HTTP
ingress peer must combine the `kubevirt` namespace selector with the pod
label `kubevirt.io: virt-api`, limited to TCP 5006. See the companion
`homelab-apps` policy and private-access instructions for that allowance.

### GitOps and VM lifecycle

Change `actual/virtualmachine.yaml` `spec.runStrategy` in Git:

- `Always`: normal operation and automatic recovery.
- `Halted`: durable stop, including during disk backup.

Flux considers `Halted` healthy only once the VM reports `Stopped`;
`Stopping` remains pending. Missing initial controller status is retried by
Flux until its health timeout.

Use the Git commit as desired state. An emergency imperative stop requires
suspending reconciliation first, otherwise Flux will restore the Git value.
For a restart without a lasting configuration change:

```bash
sudo actual-pilot-virtctl -n actual-pilot restart actual-pilot
```

Routine reconciliation must preserve a test budget. Test a harmless metadata
drift and a Git stop/start change after deployment. An in-cluster HTTP probe
must run from namespace `actual-pilot-probes`, with restricted pod security;
the guest firewall and namespace NetworkPolicy remain part of that test.

## Storage, backup, and restore acceptance

The PVC requests are 20 GiB root / 10 GiB data. Filesystem-mode CDI reserves
overhead, so the guest data device can be slightly smaller than 10 GiB.
PV reclaim policy is `Retain`, storage reconciliation has pruning disabled,
and durable resource deletion is protected. Namespace-wide policy pruning is
also disabled intentionally; remove obsolete policies explicitly after review
when tightening them, since Kubernetes policies are additive.
The registry root import uses CDI's node pull method, which needs no
dynamic scratch PVC. No dynamic storage provisioner is installed.

The host refuses a fresh cluster database with nonempty pilot disk
directories, including when an ownership marker survives database loss.
Do not bypass that guard to recreate DataVolumes: an importer can overwrite
`disk.img` before any guest disk check runs. Preserve the images and use a
deliberate database/PVC recovery procedure; automatic adoption is excluded.

Data survives VM restart. It must also survive a restore test before this
pilot is considered reliable enough for accepted data:

1. Put the VM in `Halted` through Git and wait until its VMI has gone.
1. Copy **both** stopped `root/disk.img` and `data/disk.img` into a new,
   timestamped directory on a selected independent backup filesystem. Use
   sparse-aware copies, avoid overwriting any existing destination, and
   compare SHA256 checksums before proceeding. A snapshot on the same pool
   supplies rollback but is not an independent backup.
1. Restore those files into fresh `restore-test/root` and `restore-test/data`
   directories, leaving the original files intact. Define separate retained
   PVs/PVCs and a separately named restore VM/Service. Bind these restored
   disks directly as PVC volumes; do **not** put restored images behind a
   blank/image-import DataVolume that could overwrite them.
1. Reuse the data-disk serial and matching guest configuration. Start the
   restore VM privately and verify the test budget through its own forwarded
   Service. Check the guest agent and restart persistence again.
1. Keep both copies until the results are reviewed. Disk or storage-resource
   deletion is a separate explicit operation, not part of this runbook.

Cloud-init runs on first boot. Editing its Secret does not reprovision an
already initialized root disk. Root-image/provisioning upgrades need a new
root disk identity and path with the existing data disk retained; do not
patch immutable DataVolume fields or erase the old root automatically.

Full Blizzard reboot acceptance remains a separately scheduled gate because
it interrupts production MicroVMs. Report deployed, VM-restart-tested,
restore-tested, and host-reboot-tested states separately.

## Disable or roll back

Suspend pilot reconciliation, stop the pilot VM and confirm the VMI has
exited, then disable `sys.virtualisation.actualPilot.enable` in host config.
Review the resulting activation plan before an authorized switch. k3s uses
`KillMode=process`; stopping its service alone is not proof that containerd
shims/VMs have stopped. Preserve all disks and cluster state. Do not use a
host-wide Kubernetes cleanup script, flush firewall tables, or change
production ingress as part of pilot rollback.
The dedicated `inet actual_pilot_control` table intentionally persists when
its service stops. After confirming all pilot runtimes have exited, remove
only that table in a separately reviewed rollback operation.
