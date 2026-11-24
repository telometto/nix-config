# SearxNG: first private KubeVirt migration preview

Status: approved for autonomous implementation. Production cutover is a later gate.

## Intent and first target

Continue PR #5894 from the validated Actual platform, starting with the simplest
running workload. SearxNG has a locally generated signing key and a local Valkey
cache; its current configuration declares no media library or application
database dependency. A fresh preview can exercise search without copying
production data or changing the existing search endpoint.

The user's goals are GitOps and easier VM management. Keep production MicroVMs
running, use bundled k3s networking, and prepare each migration before activating
it. Off-host backup work is deferred; rsync.net is the destination for later.

## Approaches

- Reuse the Actual pattern: a digest-pinned Debian cloud root, guest bootstrap,
  systemd and a pinned application container. This reuses tested DHCP, guest-agent,
  private forwarding and retained-storage boundaries. This is the proposed choice.
- Build a NixOS guest image from the existing service module. This offers closer
  configuration reuse but introduces an image build/distribution pipeline before
  the first additional service proves the migration process.
- Run a native Kubernetes application Pod. This is smaller but changes the
  established VM isolation model, so it is outside this first migration.

The first option is the implementer's proposed choice, based on the already
approved platform. This document adds the service-specific staging boundary.

## Proposed parts

1. Reuse the current k3s, Flux, KubeVirt and CDI installations. Add independent
   Searx storage/application Flux layers and a `searx-preview` namespace. The
   application and storage layers are suspended by default, so publishing their
   definitions does not start a VM or importer.
1. Add a Nix host preview option, disabled by default. When explicitly enabled,
   it adds only the new root directory to the existing retained-disk guard and
   creates its parent directories. The normal configuration keeps the existing
   guard inputs and production service definitions unchanged.
1. Use a separate retained 20 GiB root PV/PVC rooted at
   `/flash/enc/vms/kubevirt-pilot/searx-preview/root`. Import the same pinned Debian
   base using CDI node pulling. Never reference an existing MicroVM image or the
   Actual root/data paths. Reject symlinks and refuse automatic import when a
   fresh cluster database coincides with retained preview images.
1. Give the preview one vCPU and 2 GiB guest memory, matching the current Searx
   allocation. Keep Valkey inside this guest on loopback, with disposable cache
   data. Keep the preview signing key on its retained root; generate it locally
   once without publishing it in Git, guest-console output or Kubernetes data.
   Existing production signing keys and secret-bearing files remain untouched.
1. Run the official SearxNG container pinned by digest. First-boot cloud-init
   installs the generic service runner, named-NIC DHCP profile and guest agent.
   Deliver the desired image reference and public application settings in a
   separate ConfigMap-backed, read-only VM configuration disk, consumed on every
   boot. Updating that ConfigMap in Git followed by a controlled Git stop/start
   must apply the new image/settings on the same retained root, preserving its
   locally generated signing key. A ConfigMap edit alone does not restart the VM.
   Cached-image startup must continue working offline. Preserve rate limiting,
   image proxying, POST search and the intended engine preferences from the public
   Nix service settings. Validate those settings against the pinned image rather
   than silently disabling unsupported controls.
1. Declare only private HTTP access, initially TCP 8080. Use a ClusterIP Service
   and a policy selecting only this preview. Permit HTTP from the probe namespace
   and from `virt-api` pods within `kubevirt`, with both selectors in one peer.
   Allow DNS and public web requests needed by the configured engines; retain the
   private-network, tailnet and metadata-address exclusions. Valkey has no guest
   network port exposed to the Pod or host.

## Implementation scope and validation

The umbrella uses `dev/kubevirt`, with `dev-kubevirt` retained as its synchronized
compatibility head for PR #5894. Shared host preparation belongs on
`dev/kubevirt-base`; the SearxNG host branch `dev/kubevirt-searxng` stacks on it.
Companion application manifests use `dev/kubevirt-searxng` in homelab-apps.
Commit with co-author attribution, push finished branches and open draft PRs;
do not merge. Preserve unrelated local work.

Add regression coverage for default suspension, disjoint retained storage,
private policy peers/ports, guest startup dependencies, per-boot configuration
consumption and the service's cached startup. Keep the existing Actual checks
passing. Validate manifests against the pinned KubeVirt/CDI schemas and build the host configuration before proposing
activation. Compare the activation preview against the running generation and
stop if it would interrupt production MicroVMs. A successful build is not
activation or live service acceptance.

Later authorized preview acceptance must establish guest-agent and HTTP readiness,
working search requests, limiter/cache connectivity and private forwarding.
Then change a visible application setting through Git, stop/start the preview
through Git and verify the new setting with the same retained root identity.
Exercise an image-reference update and reversal with pinned images before calling
the application management workflow accepted. Compare production MicroVM PIDs
before and after. Current production Searx and its HTTP route remain the rollback throughout.

## Gates and remaining builder choices

This preparation does not activate the host option, resume the Flux layers,
change a production route, stop a MicroVM, or delete any disk or acceptance copy.
Activation and production cutover each need a concrete reviewed result first.
Before any eventual production-data migration, revisit the deferred backup gate.

The builder selects and records the official image digest, supported settings
mapping, configuration-disk reader, guest Valkey packaging, exact public-web
egress ports and test commands.
These choices must preserve the boundaries above. Broader networking, replacing
the public HTTP edge, platform renaming and other service migrations are excluded.

## Primary references

- [SearxNG container deployment](https://docs.searxng.org/admin/installation-docker.html)
- [SearxNG server settings](https://docs.searxng.org/admin/settings/settings_server.html)
- [Validated Actual pilot runbook](../../actual-kubevirt-pilot.md)
