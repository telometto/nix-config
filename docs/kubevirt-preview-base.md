# Private KubeVirt preview host base

The validated Actual platform can reserve retained disks for independent previews.
This registry prepares storage only. It does not define or start a VM, change a
production MicroVM, expose a service or resume a Flux layer.

```nix
sys.virtualisation.actualPilot.previewVMs.example-preview = {
  enable = false;
  disks = [ "root" ];
};
```

Names and disk names must be unique DNS labels. `actual`, `actual-pilot` and
`restore-tests` are reserved. Every enabled disk stays below
`/flash/enc/vms/kubevirt-pilot/<preview>/<disk>`; callers cannot supply an arbitrary
host path. Disabled declarations leave the existing preflight inputs unchanged.

On the next authorized host boot/start, the existing k3s preflight validates all
paths before creating preview directories. It rejects symlinks in any ancestor,
unknown nonempty preview directories and any nonempty disk directory when the
cluster database is missing. Registration records live in the isolated cluster
state at `/var/lib/rancher/k3s-actual-pilot/preview-disk-owners`, outside the PVs.
They allow an already registered preview to reuse its images on subsequent starts.
The guard reads metadata only; it never opens an image or legacy credential file.
Disabling a declaration does not remove its directory, image or registration.

Both sides need deliberate rollout: enable the service's host declaration, build
and inspect the activation preview, then activate only with separate permission.
Only after host preparation passes may its storage Flux layer be resumed; only
after import succeeds may its application layer be resumed. A new host guard input
changes k3s preStart, so activation can restart k3s: assess that separately before
using a live switch. Never clear a failed guard by deleting retained disks or the
cluster database. Recovery/adoption requires a separate reviewed procedure.

The canonical umbrella branch is `dev/kubevirt`; `dev-kubevirt` remains the
compatibility head of PR #5894. Keep them at the same reviewed commit when
advancing the umbrella. Service branches stack on `dev/kubevirt-base` and retain
independent draft PRs until review and deployment gates are met.

Public verification (use the stable nixpkgs revision locked by this repository):

```bash
nix-build --no-out-link --expr 'import ./tests/actual-pilot-check.nix { nixpkgs = /path/to/locked-nixpkgs; }'
```

This exercises fixture-only first registration/recovery and the public Nix
contract. It does not activate the host or establish live preview readiness.
