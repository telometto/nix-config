# Reliable Actual KubeVirt pilot

Status: approved on 2026-11-23 for implementation; stop before activation.

## Intent and agreed scope

The user wants GitOps and easier VM management. The first milestone is a
reliable Actual Budget VM on Blizzard, based on current `nix-config/main`,
while the production MicroVMs continue running. This is a fresh pilot with
disposable test budgets, not a migration of existing Actual data.

The user has agreed to the goal and preservation of production. The choices
below are implementation proposals, not additional decisions attributed to
the user.

## Starting point, checked on 2026-11-23

- Nix configuration base: `b1dcb3ea5ab36782101346da8205f85e7db18896`.
- Companion `homelab-apps/main`: locally fetched
  `e55de4341dba4491aaccd6858f3c0aba6fa618d5`; recheck before branching.
- Blizzard runs 18 production MicroVMs, host Traefik, and a Cloudflare Tunnel.
  The Actual MicroVM is inactive. k3s/bootstrap units are absent.
- `/dev/kvm` exists. Available RAM was approximately 31 GiB; VM storage had
  approximately 2.9 TiB free. These are observations, not reserved capacity.
- Existing routes include `10.100.0.0/24`, `10.100.1.0/30`, the LAN, and
  Tailscale. No `10.44.0.0/16` or `10.45.0.0/16` route was observed.
- `homelab-apps` is public. Its existing `flux/` root installs Cilium,
  MetalLB, and a Traefik configured with host ports 80/443. That root cannot
  be used for this additive pilot.
- Local `homelab-apps/templates` commit `9944bcc` contains unfinished
  hardening. Preserve it and its checkout; port selected non-secret changes
  deliberately instead of merging it wholesale.

## Approaches

1. Revive PR #5894 and its complete Cilium/ingress migration. This carries
   stale host configuration and public-ingress changes into a small pilot.
1. Add a new pilot using bundled k3s networking, Flux, KubeVirt, CDI, and
   Actual. A separate GitOps root excludes the old ingress/network stack.
   This is the recommended approach: it exercises the desired GitOps and VM
   lifecycle with fewer bootstrap dependencies.
1. Run the Kubernetes node inside another VM. That gives a stronger
   separation from host routing, but adds nested virtualization and another
   guest lifecycle to the first milestone.

Choose approach 2 for this design. Cilium can be evaluated separately if a
concrete requirement later calls for it. This choice does not promise that
host-level Kubernetes networking has zero production risk; coexistence is a
required deployment gate.

## Ownership and repository layout

`nix-config` owns the host service, package pins, bootstrap seed, isolated
state locations, narrowly scoped firewall changes, and a runbook. Reuse the
upstream NixOS k3s service and repository auto-loading conventions. Keep
pilot-specific configuration opt-in and disabled on the other hosts. Avoid
changing the defaults of the existing shared k3s wrapper for other users.

`homelab-apps` owns the Flux controller desired state, dependency-ordered
Kustomizations, KubeVirt/CDI operators and CRs, static storage, and Actual.
Add a self-contained tree under `clusters/blizzard-actual-pilot/`. Its build
graph must not reach existing `flux/`, `network/`, `ingress/`, `vms/`, or
secret manifests. Reuse material by reviewed copies into this tree.

The host seeds pinned Flux components and a GitRepository/root Kustomization
only into the new cluster state. Flux then owns its controllers and the
pilot resources from that path. The seed must not continually overwrite a
newer Flux-managed spec or roll controller versions back on host restart;
initial seeding is guarded by API object presence, and deliberate controller
updates are made in Git. Git source uses public HTTPS with no GitHub token
or deploy key. Its accepted source branch is `main`; a review branch may
be used for explicit pre-merge acceptance, then switched to `main`.

## Host and cluster isolation

- Use new k3s state at `/var/lib/rancher/k3s-actual-pilot` and an explicit,
  generated public configuration file. Do not load the old default k3s
  configuration or auto-apply directory.
- Write the admin kubeconfig to
  `/etc/rancher/k3s-actual-pilot/k3s.yaml`, root-owned mode 0600. Do not read
  or copy an existing kubeconfig, token, or private key.
- Explicitly select the `k3s_1_35` package from the current locked nixpkgs;
  its inspected version is `1.35.10+k3s1`. Freeze compatible maintained
  KubeVirt, CDI, Flux, Debian image, and Actual versions before code is
  finalized. Verify release compatibility using official sources and record
  exact versions, URLs, and hashes/digests in the implementation.
- Keep bundled Flannel, kube-proxy, CoreDNS, and network-policy enforcement.
  Disable bundled Traefik and ServiceLB. Do not install another ingress
  controller, MetalLB, Cilium, or a custom containerd template.
- Use pod CIDR `10.44.0.0/16`, Service CIDR `10.45.0.0/16`, and DNS Service
  `10.45.0.10`. Recheck overlap before activation. The API's advertised node
  address must be reachable by pods; binding it only to loopback must not
  break ClusterIP routing. Administrative access remains local via SSH.
- Keep the host firewall enabled. Do not globally trust pod interfaces,
  disable reverse-path filtering, flush firewall tables, change MicroVM
  bridge policy, or expose Kubernetes ports publicly. Allow only verified
  required pod-to-host control-plane traffic on the pilot interfaces.
- Do not modify production MicroVM definitions, autostart, publication,
  bridge/routing configuration, host Traefik/cloudflared, or CrowdSec.
  Review the evaluated host diff for these invariants before activation.
- Check the upstream service's staging/cleanup paths against the custom data
  directory, including shared kubelet/CNI/containerd runtime locations;
  `--data-dir` alone is not proof that every path is isolated. Account for
  any stale cluster runtime without inspecting credentials or deleting old
  state. Do not use generic k3s uninstall/kill-all scripts in rollback.

## Actual VM and storage

Create `VirtualMachine/actual-pilot` in namespace `actual-pilot`, with 1 vCPU
and 1 GiB guest RAM plus explicit Kubernetes requests accounting for VM
overhead. This pilot must not expand into other workloads automatically.

Use a pinned Debian 13 cloud image imported by CDI, with separate retained
20 GiB root and 10 GiB data volumes. Static PVs use an immediate-binding,
no-provisioner StorageClass, explicit matching, and Blizzard node affinity.
New host paths are under `/flash/enc/vms/kubevirt-pilot/actual/` with distinct
root and data subdirectories. Do not reuse, inspect, format, or remove old
MicroVM or KubeVirt pilot disks. Every filesystem creation must be limited
to a positively identified new blank pilot data disk; an unexpected existing
filesystem causes a failure, not an automatic format.

Guest provisioning is idempotent and logs progress to the console. It
installs/starts qemu-guest-agent and runs a pinned Actual container through
systemd/Podman with host networking inside the VM. This removes the second
Podman bridge/NAT from the former pilot. Actual data is mounted from the
separate disk at a stable path; service startup requires that mount. Root
and password SSH login are disabled. No private SSH material, production
budgets, bank credentials, tunnel tokens, or other real secrets enter Git.

Use DHCP networking and its provided MTU/DNS first. Test guest DNS, HTTPS
downloads, and application reachability; add a workaround only for a
reproduced issue. Use bounded retry/timeouts for first-boot provisioning and
a durable completion marker. Select a supported cloud-init/configuration
delivery mechanism without introducing real secret material or relying on
unbounded inline payload size. New non-secret provisioning payloads can be
generated; existing files named as secrets remain outside the inspection
scope without the user's permission for each exact file.

## GitOps and VM operations

Git owns the VM definition, resources, image pins, policies, and desired power
state. Use `runStrategy: Always` for accepted normal operation and a Git
change to `Halted` for a durable stop. `virtctl restart` supplies the routine
restart operation; the runbook distinguishes it from configuration changes
that require a VM restart to take effect.

Flux corrects drift in the desired resources. Protect PV/PVC/DataVolume
deletion and operator CR deletion from routine pruning. Stopping a VM,
reconciling Flux, or removing an application manifest must never implicitly
erase a disk. Root-disk upgrades use a deliberate replacement procedure;
they must not try to patch immutable CDI fields or automatically delete
retained data. Document storage decommissioning separately.

Expose only a ClusterIP Service on Actual's usual TCP 5006. Browser access
uses an explicit loopback-only port-forward plus SSH tunnel, with a
localhost browser URL. Do not add host ports, NodePorts, public DNS, or
Cloudflare/Traefik routes. NetworkPolicy defaults to deny in the application
namespace, permits required DNS and controlled bootstrap/update HTTPS, and
prevents application access to production private networks. Verification
probes get a dedicated, explicit allowance. Admin port-forward traffic and
operator/importer policy needs are checked separately.

The runbook covers status, reconcile, durable stop/start through Git,
restart, guest-agent/console diagnostics, UI access, backup, restore,
and disabling the pilot while keeping its storage.

## Reliability and acceptance

Local/CI validation must establish:

1. Focused Nix evaluation proves other hosts stay disabled, intended k3s
   configuration is generated, paths are isolated, and bundled ingress is
   disabled. Use public fixtures, not private secret files.
1. The pilot Kustomize build is reproducible and schema-validated against
   the pinned APIs; it excludes the legacy roots, host ports, NodePorts,
   production disks, real secrets, and mutable image tags.
1. Flux dependencies separate CRD/operator installation, operator CRs,
   storage, and the VM. Healthy objects alone are not application readiness.
1. Configuration/bootstrap failures report an actionable error and bounded
   retry. A host service restart does not replay the obsolete cluster or
   reset newer Flux-managed desired state.

Live acceptance, after the user explicitly authorizes host activation:

1. Capture production MicroVM unit states, representative existing HTTP
   service health, routes, and network-policy state before and after.
1. New node/networking, Flux, KubeVirt, and CDI become ready; image import
   completes; Actual responds through the intended access path and its guest
   agent is connected. Repeated reconciliation creates no duplicates.
1. A harmless metadata drift is reconciled; a Git power-state change is
   honored. A VM restart preserves a disposable test budget.
1. Back up quiesced pilot app data to a separate backup location and restore
   it into separate new pilot storage. Compare test data and verify Actual
   reads it. Leave original and restored copies available until reviewed.
   A same-pool snapshot is useful rollback, not an independent backup.
1. Test a controlled pilot service recovery while production checks stay
   healthy. Full Blizzard reboot recovery remains a separate scheduled gate:
   rebooting now would stop production MicroVMs and needs explicit approval.

Do not call the pilot fully reboot-validated or backup-validated before the
corresponding live tests occur. Report prepared, deployed, VM-tested,
restore-tested, and host-reboot-tested states separately.

## Deployment boundaries and rollback

Prepare all code, checks, resource pins, and exact activation/acceptance
commands for review before requesting deployment. Current repository
`AGENTS.md` forbids `nixos-rebuild switch` unless explicitly requested.
Compare the proposed generation with the actual running generation and
inspect the activation plan, including MicroVM install/update/reload units.
Building from current `main` can incorporate unrelated changes accumulated
since the running generation. Do not activate if the plan would stop or
restart production MicroVMs; resolve that conflict before requesting a
deployment decision. A maintenance window would be a change of user scope.
Any destructive operation needs a concrete command and appropriate user
authorization; no disk deletion is required for initial deployment.

If coexistence checks fail, suspend pilot reconciliation, stop the new VM,
and disable only the pilot service/configuration. Preserve new and old
storage. Do not run host-wide network cleanup or alter production ingress.
Full-host rebuild/rollback procedures must account for unrelated changes in
the running generation and must not be represented as instantaneous.

## Explicitly excluded from this milestone

Production data migration, public ingress cutover, Cilium evaluation,
gVisor, HA/live migration, distributed storage, media sharing, VPN gateway
design, bank connections, and a VM-management dashboard.

## Sources for implementation

- Current `nix-config/AGENTS.md`, shared k3s module, Blizzard host config,
  MicroVM network policy, and CI reference at the base commit above.
- [K3s packaged components](https://docs.k3s.io/installation/packaged-components)
- [K3s network options](https://docs.k3s.io/networking/basic-network-options)
- [K3s server configuration](https://docs.k3s.io/cli/server)
- [Flux GitRepository configuration](https://fluxcd.io/flux/components/source/gitrepositories/)
- [KubeVirt Kubernetes support matrix](https://github.com/kubevirt/sig-release/blob/main/releases/k8s-support-matrix.md)
- [KubeVirt GitOps](https://kubevirt.io/user-guide/cluster_admin/gitops/)
- [KubeVirt networking](https://kubevirt.io/user-guide/network/interfaces_and_networks/)

## Authorization

The user approved the additive pilot, bundled k3s networking, private
access, and implementation on 2026-11-23. Keep production MicroVMs running
and stop before activation. Version pins and detailed provisioning
mechanics are engineering choices to verify during implementation.
