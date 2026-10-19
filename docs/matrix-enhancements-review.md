# Matrix enhancements review

Updated on 2026-10-19 for `patch/2026-10-18-matrix-enhancements`.

Matrix login, rendezvous, and client-IP enhancements were originally committed
on `main`. This branch retains that published history and adds an explicit
rollback/reapplication pair for review. At reviewed head
`9b4804aa032f215564a7020d4e88b0bd7cadb42e`, production Nix files match the
upstream base below; the additional rendezvous session-path test is the only
net Nix change at that revision. This document records the extraction and its
acceptance boundary. The later local follow-up is described separately below.

## Commit boundaries

| Role | Commit |
| --- | --- |
| Refreshed upstream base | `7a25c0e5dd224be073db6c3cfd04f5249ee2964b` |
| Matrix-only rollback and review base | `bf135affeaff2e1c5d12ece80d2d7c02bcc56589` |
| Reviewed reapplication, including the test fix | `034b7c32ad58995d16c8c29036e1a6811e95959a` |

The core review comparison is:

```bash
git diff bf135affeaff2e1c5d12ece80d2d7c02bcc56589 \
  034b7c32ad58995d16c8c29036e1a6811e95959a -- \
  lib/traefik.nix tests/matrix-baseline.nix vms/matrix-synapse.nix
```

It contains exactly three files, with 176 insertions and 51 deletions.
The six original functional commits are `e13ccfed`, `aa9edd9b`, `092f9067`,
`11b36d32`, `f23d3beb`, and `a728c081`. The rollback commit message retains
all six expanded hashes. The contribution from merged side ancestry is included.
Both temporary passwordless sudo pairs cancel and are excluded from replay.

Byte comparisons prove that the rollback restores the three historical
baseline files and the reapplication restores the reviewed final files.
All intervening lockfile updates, the private-input revision, earlier Matrix
infrastructure, and unrelated changes are preserved.

## Review result

The `pr-review-expert` review found no blocking source defect in this scope.

| Area | Evidence and result |
| --- | --- |
| Security | Client-IP rewriting is scoped to the Matrix vhost and its gateway/loopback proxy hops. Proxied routes replace both client-IP headers, and Synapse administration remains denied. No credentials or dependencies enter the patch. |
| Correctness | MAS device routes retain explicit boundaries. Exact and prefix rendezvous locations preserve routing and strong ETags for conditional writes. Discovery and administration contracts remain intact. |
| Code quality | The canonical-header transformation covers every proxied location and preserves explicit HTTPS forwarding, WebSocket settings, and return-only locations. |
| Races and lifecycle | The fixture binds MAS before starting Synapse readiness and tracks their shared process. Production service and secret-generator lifecycle are unchanged. |
| Maintainability and tests | The client-IP loop now includes `/_synapse/client/rendezvous/test-session`. The existing ETag test remains. A session-only header mutation escaped the old loop and failed the updated one. |
| Documentation | The original extraction preserved unfinished Matrix documentation in a stash. The user subsequently restored that work; the historical extraction evidence below does not describe the current worktree. |

### Local review follow-up

The subsequent six-axis review reproduced a fixture weakness: MAS and Synapse
returned the same session payload and ETag, so routing the session to MAS still
passed. The local follow-up makes MAS reject Synapse-only rendezvous traffic
and checks the responding backend. Exact and prefix rendezvous contracts now
drive route and client-IP probes, with coverage required for every proxied
location. The fixture also covers creation at the MSC4108 Matrix endpoint,
strong/weak conditional writes, bounded startup/requests, and dynamic ports.
The production Nginx configuration is unchanged by this follow-up.

The extraction validation below applies to its pinned revision. Validation of
later local changes must be reported separately; earlier CI does not validate
an uncommitted worktree. These mocks do not prove real login, QR linking, or
live backend attribution. Current roadmap status and historical operator
acceptance remain in the [Matrix hardening plan](matrix-hardening-plan.md).

## Validation

The actual Matrix baseline check passed during the initial extraction review,
using the NixOS-generated Nginx config: 52 route/discovery probes, 174 client-IP
cases across 29 paths, and the strong ETag/conditional PUT check. The reviewed
source files are byte-identical to that validated version. The targeted checks
for the refreshed branch are:

```bash
nix build --no-link --no-write-lock-file --no-update-lock-file \
  .#checks.x86_64-linux.matrix-baseline \
  .#checks.x86_64-linux.matrix-whatsapp-bridge
nix build --no-link --no-write-lock-file --no-update-lock-file \
  .#checks.x86_64-linux.formatting
git diff --check
```

Both focused Matrix checks passed on the reapplication commit with the refreshed
lockfile. Parsing, statix, and the committed diff's whitespace check also passed.
The full formatting check and final CI gate are checked on the completed branch.

The repository formatter now runs successfully with the normal binary cache.
The earlier `--offline` invocation forced an unnecessary source bootstrap and
hit a fixed-output source hash mismatch. Normal cache use reduced preparation
to a 19.1 MiB download and two wrapper derivations. No source hash, lockfile,
or persistent Nix configuration was changed to bypass that mismatch.

The initial mutation check used the actual built test shell and generated
Nginx config, changing only temporary ports/paths and removing only the session
location's canonical `X-Forwarded-For` directive. The old loop passed that
mutation; the new loop rejected it. All temporary fixture processes exited.

Final CI results must be checked on the exact PR head. Required branch checks
are `format` and `flake-check`; host validation is additional evidence. Builds
and tests do not establish live Cloudflare-to-Traefik attribution or production
acceptance. No host/VM activation or deployment is part of this change.

## Preserved local work

At extraction, all 23 prior changed paths, including six untracked files, were
preserved in stash `ebea433edb2f83db62eb9200e83d4de33d29253e`. Byte and
executable-mode comparisons passed at that time. The user subsequently
restored all 23 paths to the worktree; preserve that work and do not repeat
restoration. The original `docs/matrix-extraction-checklist.md` can also be
located in that stash's untracked-files parent if the stash is retained:

```bash
git show ebea433edb2f83db62eb9200e83d4de33d29253e^3:docs/matrix-extraction-checklist.md
```

The two earlier `codex/matrix-review` and `codex/matrix-rollback` worktrees
remain intact. The current commit evidence is under
`/tmp/nix-config-matrix-integration-20261019.z8f31rvn`; the initial source and
mutation evidence is under `/tmp/nix-config-matrix-enhancements-20261018.v2b1yonj`.
Those temporary artifacts may be cleaned up, while the committed comparison
above remains reproducible from Git history.

## Integration requirement

At the reviewed head, a PR targeting the upstream base above shows the net test
fix and this record because the inverse pair cancels in that comparison.
Review the full three-file change against the rollback commit shown above,
and review any subsequent follow-up changes separately.

Retain both commits and integrate the completed branch using an explicit merge
commit after the user's final approval and passing CI. Do not deploy or leave
shared `main` at the intermediate rollback state. The user's local work has
already been restored; this record does not authorize any further stash action,
merge, or deployment.
