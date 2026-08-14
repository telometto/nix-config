# Handoff — Blizzard paranoid-NixOS hardening

## Goal of next session

Begin R-12 and R-13 from current `main`: establish the flake-native deployment
and provenance contract on a disposable target, then audit Blizzard host and
VM boundaries. Keep activation, target-side auto-upgrade changes, storage
changes, and persistence changes behind the gates below.

## State of play

- Done:
  - Reviewed the 2021 paranoid-NixOS article and the decision-relevant links; its durable principles and configuration caveats are recorded here — `docs/2026-08-14-blizzard-paranoid-nixos-handoff.md`
  - Compared those principles with Blizzard's current server role, SSH policy, auto-upgrade path, audit/CrowdSec coverage, MicroVM baseline, and inactive disko wiring — `modules/role-server.nix`, `modules/services/auto-upgrade.nix`, `modules/services/openssh.nix`, `hosts/blizzard/security/crowdsec.nix`, `modules/virtualisation/microvm-base.nix`, `docs/2026-08-13-blizzard-intrusion-audit.md`, `docs/explanation-design.md`
  - Added R-12, R-13, and R-14 and extended the existing logging, exposure, and provenance initiatives instead of creating duplicates — `docs/roadmap.md`
  - Indexed this durable handoff — `docs/README.md`
  - Read-only validation passed for the handoff, redaction, targeted formatting, path checks, `nix flake check --no-build`, Statix, and the Blizzard toplevel build — `docs/2026-08-14-blizzard-paranoid-nixos-handoff.md`, `flake.nix`
- In flight:
  - R-12 will add a pinned `deploy-rs` input and `deploy.nodes.blizzard` referring to `self.nixosConfigurations.blizzard`; this documentation pass intentionally adds no flake or deployment code — `docs/roadmap.md`, `flake.nix`
  - R-13 will audit physical-host SSH, Nix daemon access, service users, systemd sandboxing, and explicit LAN/Tailscale exposure, preserving the stronger compatible MicroVM controls — `docs/roadmap.md`, `hosts/blizzard/`, `modules/`, `vms/`
  - R-14 will evaluate tmpfs-root, impermanence, disko, reprovisioning, and global `noexec` only through a disposable image and recovery rehearsal — `docs/roadmap.md`, `hosts/snowfall/disko.nix`, `docs/tutorial-provision-host.md`
- Blocked:
  - Live activation, deployment, commit, push, secret changes, and Blizzard disk or mount changes are outside this handoff and require their explicit future gates and authorization — `docs/roadmap.md`, `docs/2026-08-14-blizzard-paranoid-nixos-handoff.md`
  - Build-enabled `nix flake check` remains blocked by the repository-wide formatting check, which would rewrite the pre-existing ordered list in `docs/matrix-hardening-plan.md`; that unrelated file was intentionally left unchanged — `docs/matrix-hardening-plan.md`, `docs/reference-ci.md`

### Article review and followed links

The article's useful model is defense in depth: minimize exposure, use
separate service identities, apply systemd `Protect*`/`NoNewPrivileges`-
style restrictions, record execution telemetry, retain logs off-host, and
make persistence explicit. It also recommends a VPN management path,
tmpfs-root, and `noexec` outside `/nix/store`, but warns that the latter
steps need repeated VM testing and a break-glass path.

The article is dated 2021 and is treated as design input, not a drop-in
configuration. Its SSH example says to disable forwarding and then sets
`AllowTcpForwarding yes`; its flat `services.openssh.*` and audit examples use
legacy option/module shapes relative to this repository; its bootstrap example
contains an intentionally unsafe placeholder password; and its config-folder,
key-list, and earlier-post links were dead or could not be reliably followed.
No article snippet or credential is copied into Blizzard.

The current NixOS manual and `systemd.exec(5)` documentation were readable and
are the authority for current option names and sandbox semantics. The
impermanence, tmpfs-root, and Erase Your Darlings references support the
separate recovery/state investigation. `nixos-anywhere` is a viable
reprovisioning aid. `deploy-rs` is selected for central flake-native
deployment; Morph remains a viable alternative, while NixOps is not selected
for a new implementation.

Sources: [article](https://xeiaso.net/blog/paranoid-nixos-2021-07-18/),
[NixOS manual](https://nixos.org/manual/nixos/stable/),
[systemd.exec](https://man7.org/linux/man-pages/man5/systemd.exec.5.html),
[deploy-rs](https://github.com/serokell/deploy-rs),
[impermanence](https://github.com/nix-community/impermanence),
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere),
[Morph](https://github.com/DBCDK/morph),
[NixOps](https://github.com/NixOS/nixops).

### Blizzard comparison and selected decisions

- Blizzard currently inherits the server role's monthly target-side
  `nixos-upgrade`, key-only SSH defaults, Tailscale, networkd, AppArmor, and
  the repository's existing host-owned MicroVM policy. The MicroVM baseline is
  stronger than the article's generic example and must remain compatible.
- Retain LAN SSH for convenience, make LAN/Tailscale source scope explicit
  through R-07, and treat Tailscale as the preferred management path. Retain
  `@wheel` Nix access and passworded sudo; do not impose root-only Nix use.
- Select `deploy-rs` with Snowfall remaining the operator. The normal
  administrative user and interactive sudo remain the activation path. CI may
  evaluate and check, but not activate hosts. Deployment checks must include
  health, configuration/lock provenance, rollback, and physical-console
  recovery.
- After a successful controlled cutover and provenance/rollback validation,
  disable Blizzard's monthly target-side auto-upgrade. Manual
  `nixos-rebuild` and physical access remain break-glass paths.
- Apply `NoNewPrivileges`, `Protect*`, `Private*`, and `Restrict*` controls
  per service only after auditing compatibility; document exceptions and test
  them. Do not turn generic article snippets into global defaults.
- Add host audit telemetry, including execution events, and connect it to the
  existing off-host retention initiative R-02. Do not create a second logging
  backend or roadmap item in this work.
- Keep tmpfs-root, impermanence, disko, reprovisioning, and global `noexec` in
  R-14. First build a disposable test image, inventory persistence, rehearse
  restore/reinstall, and verify Nix/build, storage, MicroVM, and break-glass
  compatibility before changing Blizzard disks or mounts.

### Implementation gates

1. Refresh current `main`, pin and evaluate the deployment tool, and make the
   `deploy.nodes.blizzard` output reference the existing
   `self.nixosConfigurations.blizzard`; do not activate it.
1. Use a disposable host or VM to prove deploy checks, health validation,
   generation/configuration revision and flake-lock provenance, rollback, and
   physical-console recovery. A successful build is not runtime proof.
1. Inventory host listeners and IPv4/IPv6 source scope; verify SSH forwarding
   restrictions, Nix daemon permissions, service identities, and each proposed
   systemd sandbox control with focused tests and `systemd-analyze security`.
1. Prove auditd execution events, CrowdSec/Traefik parsing and client
   attribution, off-host retention, and alerting under R-02. Investigate every
   MicroVM policy event and keep the existing audit/enforce approval boundary.
1. Only after the disposable cutover and rollback gates pass, perform a
   controlled Blizzard cutover with explicit authorization; then disable the
   target-side monthly upgrade and verify manual and console recovery.
1. Treat R-14 as a separate implementation: build the disposable image,
   inventory persistent paths, rehearse reinstall/restore, and test the
   failure modes before any Blizzard storage or mount edit.

### Validation commands

Run the narrowest applicable checks and report whether private `nix-secrets`
access allowed evaluation:

```bash
python3 /home/zeno/.codex/skills/handoff/scripts/handoff_self_check.py docs/2026-08-14-blizzard-paranoid-nixos-handoff.md
python3 /home/zeno/.codex/skills/handoff/scripts/redaction_linter.py docs/2026-08-14-blizzard-paranoid-nixos-handoff.md
git diff --check
nix fmt -- README.md docs/README.md docs/roadmap.md docs/2026-08-14-blizzard-paranoid-nixos-handoff.md
nix run 'nixpkgs#statix' -- check .
nix flake check --no-build
nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link --print-build-logs
nix flake check
```

The installed Statix accepts the `check .` subcommand; the repository's older
`--check` example was rejected. The last three Nix commands are conditional on
private-input access. They validate configuration/build state only; they do
not prove activation, deployment, runtime health, secret materialization,
rollback, or recovery.

## Open decisions

- Q: Is this handoff authorized to activate or deploy Blizzard, change its
  target-side upgrade policy, or change its disks and mounts?
  - Options considered: perform the changes now, or defer them behind the
    disposable-target, provenance, rollback, recovery, and authorization gates.
  - Lean: defer — this pass is documentation and planning only.
  - Forcing constraint: the supplied acceptance criteria prohibit activation,
    deployment, secret changes, and Blizzard storage changes here.

No product decisions remain for the initial implementation: use `deploy-rs`,
retain LAN SSH and `@wheel` Nix access, disable target-side auto-upgrade only
after controlled cutover, and keep storage/impermanence behind R-14's gates.

## Skills to use

- `handoff` — refresh this durable state if implementation spans another session.
- `code-review` — review the R-12/R-13 implementation diff against repository standards and this handoff.
- `observability-designer` — design the auditd, off-host retention, attribution, and alert acceptance gates.
- `codex-security:propose-security-hardening` — compare service-specific hardening options and exceptions against the threat model.
- `diagnosing-bugs` — investigate any disposable deploy, rollback, recovery, or compatibility failure before changing the live host.

## Artifacts

- docs/2026-08-14-blizzard-paranoid-nixos-handoff.md
- docs/roadmap.md
- docs/README.md
- docs/2026-08-13-blizzard-intrusion-audit.md
- docs/deployment-audit-2026-08-08-microvm-networking.md
- docs/reference-architecture.md
- docs/reference-ci.md
- docs/explanation-design.md
- flake.nix
- hosts/blizzard/
- modules/role-server.nix
- modules/services/auto-upgrade.nix
- modules/services/openssh.nix
- modules/virtualisation/microvm-base.nix
- vms/base.nix
- hosts/snowfall/disko.nix
- docs/tutorial-provision-host.md
- https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
- https://github.com/serokell/deploy-rs
- https://github.com/nix-community/impermanence
- https://github.com/nix-community/nixos-anywhere
- https://github.com/DBCDK/morph
- https://github.com/NixOS/nixops
