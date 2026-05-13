# KubeVirt Migration — Plan 1: Cluster Bootstrap

> **Revised 2026-05-05.** The original plan (Tasks 1–16) had Flux bootstrapped before Cilium,
> which deadlocks. This revision corrects the order, fixes all known incorrect values, and
> introduces a NixOS module (`sys.services.k3s.bootstrap`) that automates bootstrap ordering
> via a helmfile-driven systemd timer — matching the pattern from niki-on-github/nixos-k3s.
> The original task sequence and execution log are preserved in Appendix A.

**Goal:** Stand up k3s on `blizzard` with Cilium CNI and Flux GitOps fully operational.
KubeVirt, CDI, MetalLB, Sealed Secrets, Traefik, and cloudflared follow via Flux reconciliation.
MicroVMs keep running untouched throughout.

**Tech Stack:** NixOS, k3s (nixpkgs), Cilium 1.19.3, flux-operator 0.33.0,
flux-instance 0.33.0 (Flux 2.8.6), KubeVirt v1.3.1, CDI v1.60.2, MetalLB v0.14.*,
Sealed Secrets v2.*, Traefik v31.\*

**⚠ Downtime:** NixOS Traefik and cloudflared are already disabled (commit `0e0a6118`).
All services are down until Traefik and cloudflared redeploy via Flux in Task 11.

______________________________________________________________________

## Why Cilium Must Come Before Flux

Flux controller pods are stuck `Pending` on a CNI-less node. Once rescheduled, they hit
`CrashLoopBackOff` because Cilium hasn't programmed its eBPF service maps — pods can't reach
the Kubernetes API ClusterIP (`10.43.0.1:443`) and crash immediately.

**Correct order:**

1. k3s starts with `--flannel-backend=none --disable-kube-proxy --disable-network-policy`
1. Cilium installs (wait until `1/1 Running`)
1. Verify pod → ClusterIP: `curl -k https://10.43.0.1:443/healthz` must return `401`, not a timeout
1. Only then install Flux (flux-operator → flux-instance)
1. Flux adopts the existing Cilium HelmRelease via the homelab-apps `network` Kustomization

The `sys.services.k3s.bootstrap` NixOS module automates steps 2–4 via a systemd timer that
runs a helmfile. The timer fires `delaySeconds` after boot and retries every 3 minutes until
both `cilium.io` and `toolkit.fluxcd.io` CRDs are present (idempotency check).

______________________________________________________________________

## File Map

**Modified in nix-config (already committed):**

- `modules/virtualisation/k3s.nix` — Cilium-compatible extraFlags including `--disable-kube-proxy`
- `hosts/blizzard/blizzard.nix` — firewall (`checkReversePath`, `trustedInterfaces = ["lxc+"]`)
- `hosts/blizzard/security/traefik.nix` — emptied stub
- `hosts/blizzard/services/cloudflared.nix` — `enable = false`
- `hosts/blizzard/virtualisation/gvisor.nix` — stubbed; gVisor deferred (see Appendix A)

**Created in nix-config (this plan):**

- `modules/virtualisation/k3s-bootstrap.nix` — helmfile-driven bootstrap module
- `hosts/blizzard/virtualisation/cilium-values.yaml` — vendored Cilium values
- `hosts/blizzard/virtualisation/flux-instance-values.yaml` — Flux sync config

**Modified in homelab-apps (this plan):**

- `network/cilium-helmrelease.yaml` — version pinned to `1.19.3`

______________________________________________________________________

## Pre-condition: clean k3s state

If the cluster has any previous (failed) Flux or Cilium bootstrap state, wipe it before proceeding.
On blizzard via SSH:

```bash
sudo systemctl stop k3s
sudo rm -rf /var/lib/rancher/k3s/
sudo systemctl start k3s   # verify it comes up clean
sudo systemctl status k3s
```

If k3s has never been successfully bootstrapped, skip this.

______________________________________________________________________

## Task 1: Verify k3s module flags (ground truth)

Already committed. Confirm the module is correct:

```bash
grep -A12 'extraFlags' modules/virtualisation/k3s.nix
```

Expected — all of these must be present:

- `--snapshotter=native`
- `--disable=traefik`
- `--disable=servicelb`
- `--disable-kube-proxy`
- `--flannel-backend=none`
- `--disable-network-policy`

If any are missing, edit `modules/virtualisation/k3s.nix` and add them to the `default` list.

______________________________________________________________________

## Task 2: Verify blizzard firewall config (ground truth)

Already committed. Confirm in `hosts/blizzard/blizzard.nix`:

```bash
grep -E 'checkReversePath|trustedInterfaces|8472' hosts/blizzard/blizzard.nix
```

Expected:

- `checkReversePath = false`
- `trustedInterfaces = [ "lxc+" ]` ← must be `lxc+`, NOT `cni+`
- No `8472` entry (VXLAN not needed with native routing)

______________________________________________________________________

## Task 3: Verify Traefik and cloudflared are disabled (ground truth)

Already committed. Confirm:

```bash
grep 'enable' hosts/blizzard/services/cloudflared.nix
# Expected: enable = false

cat hosts/blizzard/security/traefik.nix
# Expected: empty stub { ... }: { }
```

______________________________________________________________________

## Task 4: Verify gvisor.nix is stubbed (ground truth)

Already committed. Confirm:

```bash
grep 'gVisor deferred' hosts/blizzard/virtualisation/gvisor.nix && echo "OK"
```

Expected: OK (no active systemd service, just comments).

______________________________________________________________________

## Task 5: Add the bootstrap module and values files

This is the main new work. The three new files were created as part of this plan.

### Step 1: Confirm new files are in place

```bash
ls -1 modules/virtualisation/k3s-bootstrap.nix \
      hosts/blizzard/virtualisation/cilium-values.yaml \
      hosts/blizzard/virtualisation/flux-instance-values.yaml
```

Expected: all three paths exist.

### Step 2: Review cilium-values.yaml

Open `hosts/blizzard/virtualisation/cilium-values.yaml`. Confirm it matches the proven-working set:

```yaml
kubeProxyReplacement: true
k8sServiceHost: "127.0.0.1"
k8sServicePort: 6443
ipam:
  mode: kubernetes
routingMode: native
ipv4NativeRoutingCIDR: "10.42.0.0/16"
autoDirectNodeRoutes: true
hubble:
  relay: { enabled: true }
  ui:    { enabled: true }
operator:
  replicas: 1
```

This must stay in sync with `homelab-apps/network/cilium-helmrelease.yaml`.

### Step 3: Review flux-instance-values.yaml

Open `hosts/blizzard/virtualisation/flux-instance-values.yaml`. Confirm the URL and path:

```yaml
instance:
  distribution:
    version: "2.8.6"
  sync:
    kind: GitRepository
    url: "ssh://git@github.com/telometto/homelab-apps"
    ref: refs/heads/main
    path: flux
    interval: 2m
    pullSecret: "flux-system"
  cluster:
    networkPolicy: false
```

### Step 4: Pre-stage the flux SSH key secret

`flux-instance` needs an SSH key to pull from `github.com/telometto/homelab-apps`. On a fresh
cluster the `flux-system` SSH secret doesn't exist yet.

**Option A — fully automated (recommended for repeatability):**

```bash
# Generate the Kubernetes Secret YAML from your existing flux SSH key
nix run nixpkgs#fluxcd -- create secret git flux-system \
  --url="ssh://git@github.com/telometto/homelab-apps" \
  --private-key-file=~/.ssh/id_ed25519 \
  --export > flux-git-auth-secret.yaml
```

Add `flux-git-auth-secret.yaml` to your nix-secrets flake, encrypt with sops, then set in
`hosts/blizzard/blizzard.nix`:

```nix
sys.services.k3s.bootstrap.fluxGitAuthSecretFile = config.sops.secrets."flux-git-auth".path;
```

**Option B — manual on first boot only:**
Skip `fluxGitAuthSecretFile`. After Task 7 (Cilium healthy), create the secret manually:

```bash
nix run nixpkgs#fluxcd -- create secret git flux-system \
  -n flux-system \
  --url="ssh://git@github.com/telometto/homelab-apps" \
  --private-key-file=~/.ssh/id_ed25519
# Then wait for flux-instance to reconcile:
kubectl rollout restart deployment -n flux-system
```

### Step 5: Confirm blizzard.nix enables bootstrap

Confirm `hosts/blizzard/blizzard.nix` has the bootstrap block under `sys.services`:

```nix
k3s = {
  enable = true;
  bootstrap = {
    enable = true;
    ciliumValuesFile = ./virtualisation/cilium-values.yaml;
    fluxValuesFile = ./virtualisation/flux-instance-values.yaml;
    # fluxGitAuthSecretFile = config.sops.secrets."flux-git-auth".path;  # Option A
  };
};
```

### Step 6: Build and verify

```bash
nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link
```

Expected: clean build with no errors.

### Step 7: Commit

```bash
git add modules/virtualisation/k3s-bootstrap.nix \
        hosts/blizzard/virtualisation/cilium-values.yaml \
        hosts/blizzard/virtualisation/flux-instance-values.yaml \
        hosts/blizzard/blizzard.nix
git commit -m "feat(blizzard): add helmfile-driven k3s bootstrap (Cilium + Flux)"
```

______________________________________________________________________

## Task 6: Apply and reboot

```bash
# Edit locally, then on blizzard via SSH:
sudo nixos-rebuild boot --flake /path/to/nix-config#blizzard 2>&1 | tail -5
sudo systemctl reboot
```

Wait ~60s for the system to come back. Then reconnect via SSH.

______________________________________________________________________

## Task 7: Verify bootstrap timer ran and Cilium is healthy

### Watch the bootstrap timer

```bash
sudo systemctl status k3s.service
sudo systemctl status k3s-helm-bootstrap.timer
sudo journalctl -u k3s-helm-bootstrap.service -f
```

The timer fires ~180s after boot and retries every 3 minutes. A successful run looks like:

```
k3s-helm-bootstrap: running helmfile...
k3s-helm-bootstrap: done
```

Check CRDs are present (both groups required):

```bash
kubectl get crds --no-headers 2>/dev/null | grep -E 'cilium\.io|toolkit\.fluxcd\.io'
```

Expected: at least `ciliumnetworkpolicies.cilium.io` and `helmreleases.helm.toolkit.fluxcd.io`.

### Verify Cilium pods

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

Expected: `cilium-XXXXX   1/1   Running`

### Definitive connectivity test

```bash
kubectl run test --image=curlimages/curl --restart=Never --rm -it -- \
  curl -k https://10.43.0.1:443/healthz
```

**Expected: `HTTP/2 401`** — any response at all means Cilium's eBPF service maps are programmed.
A timeout or `connection refused` means Cilium is not routing service traffic correctly.

If you get a timeout:

1. `kubectl logs -n kube-system -l k8s-app=cilium` — look for eBPF load failures
1. Verify `trustedInterfaces = [ "lxc+" ]` (not `cni+`) in blizzard.nix
1. Verify `checkReversePath = false` in blizzard.nix
1. Verify `--disable-kube-proxy` is in k3s extraFlags
1. Try: `sudo systemctl restart k3s` then re-run the curl test

______________________________________________________________________

## Task 8: Verify node is Ready

```bash
kubectl get nodes
```

Expected:

```
NAME       STATUS   ROLES                  AGE   VERSION
blizzard   Ready    control-plane,master   Xm    v1.xx.x+k3s1
```

`NotReady` after Cilium is running means the node taint hasn't cleared. Check:

```bash
kubectl describe node blizzard | grep -A5 Taints
```

If `node.cilium.io/agent-not-ready` is still present but Cilium pods are Running, wait 60s and
check again — Cilium clears the taint automatically once its agent is fully initialized.

______________________________________________________________________

## Task 9: Verify Flux is reconciling

```bash
nix run nixpkgs#fluxcd -- get gitrepositories -A
```

Expected: `flux-system/flux-system   True   Fetched revision: main@sha1:...`

If the GitRepository shows `False` with an auth error, the `flux-system` SSH secret is missing.
Create it manually (Option B from Task 5 Step 4) and restart:

```bash
nix run nixpkgs#fluxcd -- create secret git flux-system \
  -n flux-system \
  --url="ssh://git@github.com/telometto/homelab-apps" \
  --private-key-file=~/.ssh/id_ed25519
kubectl rollout restart deployment -n flux-system
```

Then wait and recheck:

```bash
nix run nixpkgs#fluxcd -- get all -A
```

______________________________________________________________________

## Task 10: Confirm Cilium version pin in homelab-apps

```bash
cd ~/.versioncontrol/github/projects/personal/homelab-apps
grep version network/cilium-helmrelease.yaml
```

Expected: `version: "1.19.3"`.

If it still shows `"1.16.*"`, update it:

```bash
sed -i 's/version: "1.16.\*"/version: "1.19.3"  # pinned: 1.16.6 broke on kernel 6.18.26/' \
  network/cilium-helmrelease.yaml
git add network/cilium-helmrelease.yaml
git commit -m "fix(cilium): pin to 1.19.3 (1.16.6 broke on kernel 6.18.26)"
git push
```

After push, Flux reconciles and the HelmRelease adopts the bootstrapped Cilium install:

```bash
nix run nixpkgs#fluxcd -- get hr -A | grep cilium
```

______________________________________________________________________

## Task 11: Wait for all Kustomizations to reconcile

```bash
nix run nixpkgs#fluxcd -- get ks -A
```

Expected eventually:

| Kustomization | Status |
|---|---|
| `namespaces` | Ready |
| `network` | Ready (Cilium + MetalLB HelmReleases) |
| `sealed-secrets` | Ready |
| `ingress` | Ready (Traefik + cloudflared) |
| `kubevirt` | Ready |
| `cdi` | Ready |

Check individual operators:

```bash
kubectl get kubevirt -n kubevirt
# Expected: Phase: Deployed

kubectl get cdi -n cdi
# Expected: Phase: Deployed

kubectl get pods -n ingress
# Expected: traefik-XXXXX Running, cloudflared-XXXXX Running
```

If cloudflared shows `ErrImagePull` or `CrashLoopBackOff`:

- The `cloudflared-token` SealedSecret is missing or invalid
- Verify the `ingress/cloudflared-secret-sealed.yaml` is in homelab-apps
- Re-seal with `kubeseal` if needed (get kubeseal version from `kubectl get deployment -n kube-system sealed-secrets-controller -o jsonpath='{...image}'`)

______________________________________________________________________

## Task 12: Back up the Sealed Secrets controller key

**This is irreversible if lost.** Every SealedSecret in homelab-apps is unrecoverable without it.

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > ~/sealed-secrets-key.backup.yaml

# Encrypt with your age key before storing:
age -r "$(cat ~/.ssh/id_ed25519.pub | nix run nixpkgs#ssh-to-age)" \
  -o ~/sealed-secrets-key-backup.age \
  ~/sealed-secrets-key.backup.yaml
rm ~/sealed-secrets-key.backup.yaml
```

Store `sealed-secrets-key-backup.age` in the nix-secrets flake or another secure offline location.

______________________________________________________________________

## Task 13: Final validation

```bash
# Node ready
kubectl get nodes
# Expected: blizzard   Ready

# No unexpected non-Running pods (flux-system pods may briefly be Pending during reconcile)
kubectl get pods -A | grep -Ev '(Running|Completed)' | grep -v 'flux-system'

# All Flux resources happy
nix run nixpkgs#fluxcd -- get all -A

# MicroVMs still running
sudo systemctl list-units 'microvm@*' --state=active
```

All green = Phase 1 complete. Record it:

```bash
cd ~/.versioncontrol/github/projects/personal/homelab-apps
echo "Phase 1 complete: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> MIGRATION_LOG.md
git add MIGRATION_LOG.md
git commit -m "chore: record Plan 1 completion"
git push
```

______________________________________________________________________

## Reading order

1. **`docs/superpowers/specs/2026-05-04-microvms-to-kubevirt-design.md`** — read "Architecture
   choice: kube-proxy replacement" first to understand why the canonical config looks as it does.
1. **This document** — execute Tasks 1–13 sequentially. Stop and debug before continuing if
   any verification step fails.
1. **`modules/virtualisation/k3s-bootstrap.nix`** — read once to understand the automation.
1. **`hosts/blizzard/virtualisation/cilium-values.yaml`** ↔
   **`homelab-apps/network/cilium-helmrelease.yaml`** — keep these in sync on every Cilium change.
1. **Appendix A (below)** — only if debugging a specific failure.

______________________________________________________________________

## What's next

**Plan 2 — Container Services:** Migrate all `media`, `apps`, and `internal` namespace workloads
(arr stack, Gluetun VPN sidecar, overseerr, searx, mealie, actual, tautulli, flaresolverr).

**Plan 3 — VM Migration + Cleanup:** KubeVirt VMs (gitea, matrix-synapse, immich, firefly,
firefly-importer, paperless, wireguard, firefox, brave), then remove MicroVM stack from nix-config.

______________________________________________________________________

## Appendix A — History: Original Failed Bootstrap (2026-05-04/05)

This section documents every deviation from the original plan encountered during the first
execution. The original task ordering (Flux-before-Cilium) was wrong. Everything below is the
authoritative record of what actually happened, preserved so future debugging sessions have a
symptom→fix table.

______________________________________________________________________

### Critical bootstrap order correction

**Original plan:** Install Cilium via Flux HelmRelease → bootstrap Flux → Cilium deploys automatically.

**What happened:** All Flux controller pods (helm-controller, kustomize-controller,
notification-controller, source-controller) were stuck `Pending` because the node had no CNI.
Once manually scheduled after the containerd config issue was fixed, they entered
`CrashLoopBackOff` because Cilium hadn't programmed its eBPF service maps yet — pods couldn't
reach the Kubernetes API ClusterIP (`10.43.0.1:443`).

**Correct order (mandatory):**

1. k3s starts with `--flannel-backend=none --disable-kube-proxy --disable-network-policy`
1. Install Cilium **directly via Helm** (not through Flux) and wait for `1/1 Running`
1. Verify pod-to-ClusterIP: `kubectl run test --image=curlimages/curl --restart=Never --rm -it -- curl -k https://10.43.0.1:443/healthz` must return `401`, not a timeout
1. **Only then** bootstrap Flux
1. Flux adopts the Cilium release via the HelmRelease manifest

______________________________________________________________________

### NixOS firewall: two required changes

The NixOS firewall dropped all pod traffic by default. Two settings were missing:

**1. Reverse path filter must be disabled:**

```nix
networking.firewall.checkReversePath = false;
```

Strict rp_filter (`= true`, the NixOS default) drops packets from pod interfaces because the
source IP (in the pod CIDR `10.42.0.0/16`) doesn't match the expected return path. This caused
complete pod network failure — pods had zero connectivity to anything.

**2. Cilium's pod veth interfaces must be trusted:**

```nix
networking.firewall.trustedInterfaces = [ "lxc+" ];
```

Cilium names its host-side veth interfaces `lxcXXXXXXXX` (not `cni*`). The original plan used
`"cni+"`, which matched nothing. Without trusting `lxc+`, pod-to-host traffic (needed for pods
to reach the Kubernetes API server) was blocked by the INPUT chain.

Both changes require `nixos-rebuild switch` and a Cilium DaemonSet rollout to take effect.

______________________________________________________________________

### k3s `--disable-kube-proxy` is mandatory with Cilium

k3s has a built-in kube-proxy equivalent that manages the `KUBE-SERVICES` iptables chain. With
Cilium's `kubeProxyReplacement: true`, both systems try to handle service routing simultaneously
— Cilium via eBPF, k3s via iptables. This causes ClusterIP timeouts even after pod-to-internet
works.

**Fix added to `modules/virtualisation/k3s.nix`:**

```nix
"--disable-kube-proxy"
```

Without this flag, pods can reach the internet (eBPF masquerade works) but cannot reach any
ClusterIP (double-NAT conflict).

______________________________________________________________________

### `kubeProxyReplacement: false` does not work with k3s

Tried `kubeProxyReplacement: false` as a workaround when `true` wasn't working. This makes
Cilium defer service routing to kube-proxy — but k3s has no standalone kube-proxy process.
Result: complete pod-to-ClusterIP failure. Cilium's BPF intercepts pod traffic to ClusterIPs
but has no service maps to forward it.

**`kubeProxyReplacement: true` is the only correct setting for k3s.**

______________________________________________________________________

### Cilium native routing mode, not VXLAN

The initial Cilium install defaulted to VXLAN tunnel mode. The reference implementation
(nixos-k3s) uses native routing, which is simpler and more reliable for a single node:

```yaml
routingMode: native
ipv4NativeRoutingCIDR: "10.42.0.0/16"
autoDirectNodeRoutes: true
```

Updated in `homelab-apps/network/cilium-helmrelease.yaml`.

______________________________________________________________________

### Cilium version: 1.16.6 → 1.19.3

Cilium 1.16.6 had zero pod connectivity on kernel 6.18.26 — likely eBPF compatibility gaps.
Upgrading to 1.19.3 resolved it (in combination with the NixOS firewall fixes above; hard to
isolate which was the deciding factor).

______________________________________________________________________

### gVisor containerd config broke all pod sandboxes

The gVisor systemd service wrote a `config.toml.tmpl` to
`/var/lib/rancher/k3s/agent/etc/containerd/` that replaced k3s's entire containerd config
instead of extending it. k3s uses Go templates with variables like
`{{ .NodeConfig.AgentConfig.CNIBinDir }}` that our minimal TOML completely omitted. Result:
containerd couldn't create any pod sandbox (`FailedCreatePodSandBox: rpc error: code = InvalidArgument`), blocking even the Cilium DaemonSet pods from starting.

**Fix:** Delete the broken template file before reinstalling Cilium:

```bash
sudo rm /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
sudo systemctl restart k3s
```

The `gvisor.nix` approach needs to be redesigned to use k3s's proper template extension format
(`{{ template "base" . }}` as the first line). This is deferred — gVisor is not yet functional
on this cluster.

______________________________________________________________________

### GitHub fine-grained token needs Administration permission for Flux bootstrap

`flux bootstrap github` requires write access to repository deploy keys (GitHub API
`repos/{owner}/{repo}/keys`). A fine-grained token with only `contents: rw` is insufficient.
Add **Administration: Read and Write** to the token.

______________________________________________________________________

### `flux` CLI is not installed system-wide

Use `nix run nixpkgs#fluxcd -- <args>` anywhere a `flux` command is needed, or add
`pkgs.fluxcd` to blizzard's system packages in nix-config.

______________________________________________________________________

### After `nixos-rebuild switch`, restart k3s and wait for Cilium

`nixos-rebuild switch` restarts k3s when k3s-related options change (flags, modules). This
terminates all pods including Cilium. After the switch:

1. Run `sudo systemctl restart k3s` if pods are in a stale state

1. Wait for `kubectl get pods -n kube-system | grep cilium` to show `1/1 Running`

1. Verify pod connectivity before proceeding

1. Run `sudo systemctl restart k3s` if pods are in a stale state

1. Wait for `kubectl get pods -n kube-system | grep cilium` to show `1/1 Running`

1. Verify pod connectivity before proceeding

______________________________________________________________________

### Cilium Helm values: final working configuration

```yaml
kubeProxyReplacement: true
k8sServiceHost: "127.0.0.1"      # Cilium bootstraps via localhost, not ClusterIP
k8sServicePort: 6443
ipam:
  mode: kubernetes
routingMode: native
ipv4NativeRoutingCIDR: "10.42.0.0/16"
autoDirectNodeRoutes: true
hubble:
  relay:
    enabled: true
  ui:
    enabled: true
operator:
  replicas: 1
```

Install command (the original manual approach before the bootstrap module existed):

```bash
nix run nixpkgs#kubernetes-helm -- install cilium cilium \
  --repo https://helm.cilium.io \
  --namespace kube-system \
  --version 1.19.3 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=127.0.0.1 \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes \
  --set routingMode=native \
  --set ipv4NativeRoutingCIDR=10.42.0.0/16 \
  --set autoDirectNodeRoutes=true \
  --set "hubble.relay.enabled=true" \
  --set "hubble.ui.enabled=true" \
  --set operator.replicas=1
```
