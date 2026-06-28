# Static Security Audit - 2026-06-27

This report captures a local-first static security audit and hardening pass for
the `telometto/nix-config` NixOS flake on `main`.

The audit did not inspect private secret material, query GitHub security state,
modify Cloudflare policy, or perform live service testing. Runtime validation
for public routes and private `nix-secrets` backed full evaluation remains a
CI or deployed-host responsibility.

______________________________________________________________________

## Executive summary

No critical source-level vulnerabilities were confirmed in this pass. The
changes focus on reducing configuration drift and making risky exceptions more
explicit:

1. Shared Traefik CSP defaults now deny inline/eval scripts.
1. Known CSP compatibility exceptions remain named and route-scoped.
1. Host role selection is now mutually exclusive.
1. MicroVM registry allocations are checked for duplicate CID, MAC, IP, and
   port values.
1. Trigger.dev no longer permits open magic-link email access unless explicitly
   opted in.
1. The scheduled security workflow now also scans pull requests and pushes.

______________________________________________________________________

## Scope and validation

### Reviewed areas

- Traefik/CrowdSec route security headers and public route exceptions.
- MicroVM registry allocation and Blizzard's enabled VM exposure map.
- Trigger.dev authentication defaults, Docker socket proxy exposure, and secret
  file handling.
- Role defaults, OpenSSH hardening, SOPS secret path bridging, and workflow
  secret scanning.
- Prior 2026-06-01 audit findings that were still source-relevant.

### Local checks

| Check | Result |
|------|--------|
| Senior Security secret scanner | Passed; 0 high/critical findings |
| Senior SecOps high-severity static scanner | Passed; 0 findings |
| Standalone MicroVM registry duplicate check | Passed; no duplicate CID, MAC, IP, or port values |
| Changed Nix file parse checks | Passed |
| GitHub Actions lint for `security-audit.yml` | Passed |
| Nix formatting | Passed; no changes after final run |
| Full flake check | Passed with `nix flake check --no-build path:.` |

### Limitations

- Full host evaluation may require SSH access to the private `nix-secrets` flake
  input.
- CSP compatibility was reviewed statically only. Browser smoke tests are still
  required for `search`, `git`, `triggers`, `matrix`, and Plex-adjacent routes.
- Live Cloudflare Access policy, CrowdSec parser state, deployed service health,
  Secure Boot, TPM2, and runtime AppArmor behavior were not validated.

______________________________________________________________________

## Findings

### F-001 - Shared Traefik CSP allowed inline/eval scripts

**Severity:** Important\
**Category:** OWASP A02 Security Misconfiguration, A05 Injection/XSS\
**Status:** Remediated in this change set\
**Confidence:** High

The shared Traefik header helper allowed `'unsafe-inline'` and `'unsafe-eval'`
in the default CSP. That made the safest path for new routes weaker than
necessary.

Remediation:

- `lib/traefik.nix` now uses a strict default CSP without inline/eval script
  allowances.
- `lib/traefik.nix` exports `compatibilityCsp` for routes that deliberately
  need legacy browser allowances.
- Blizzard's Plex-family, Lingarr, Matrix, Firefox, and Trigger exceptions
  remain named and route-scoped.

Follow-up:

- Smoke test the public routes after deployment. If a route breaks, add or tune
  a narrow compatibility middleware for that route rather than weakening the
  shared default.

### F-002 - Desktop/server role exclusivity was not enforced

**Severity:** Suggestion\
**Category:** OWASP A06 Insecure Design\
**Status:** Remediated in this change set\
**Confidence:** High

The desktop and server roles were independent booleans. A host could
accidentally enable both role bundles and merge conflicting network and service
posture.

Remediation:

- `modules/core/roles.nix` now asserts that `sys.role.desktop.enable` and
  `sys.role.server.enable` cannot both be true.

### F-003 - MicroVM registry uniqueness was documented but not enforced

**Severity:** Suggestion\
**Category:** OWASP A06 Insecure Design, A02 Security Misconfiguration\
**Status:** Remediated in this change set\
**Confidence:** High

The central registry documented CID, MAC, IP, and service port uniqueness, but
evaluation did not enforce those invariants.

Remediation:

- `modules/virtualisation/microvm-base.nix` now asserts uniqueness for
  registry CID, MAC, IP, and port values.
- `vms/vm-registry.nix` now documents `flaresolverr` as a reserved allocation
  for the service embedded in `prowlarr-vm`, not as a missing standalone VM
  output.

### F-004 - Trigger.dev email allowlist was open by default

**Severity:** Important\
**Category:** OWASP A01 Broken Access Control, A07 Identification and Authentication Failures\
**Status:** Remediated in this change set\
**Confidence:** Medium

`sys.services.trigger.auth.whitelistedEmailsFile = null` caused the generated
container environment to leave `WHITELISTED_EMAILS` empty, which Trigger.dev
uses as open email access. That is risky for a public route even when the
service is intended for a small trusted audience.

Remediation:

- `sys.services.trigger.auth.allowAllEmails` was added with default `false`.
- Trigger now asserts that `auth.whitelistedEmailsFile` is set unless
  `auth.allowAllEmails = true` is explicitly configured.

### F-005 - Security audit workflow only ran on schedule/manual events

**Severity:** Important\
**Category:** OWASP A03 Software Supply Chain Failures\
**Status:** Remediated in this change set\
**Confidence:** High

The security audit workflow scanned full git history, but only on the weekly
schedule or manual dispatch. PRs and pushes could land without the same secret
scan feedback.

Remediation:

- `.github/workflows/security-audit.yml` now runs on `pull_request` and pushes
  to `main`.
- Issue creation is split into a separate non-PR job that is the only job
  requesting `issues: write`.

______________________________________________________________________

## Deferred live validation

1. Verify response headers and login flows for enabled public routes after the
   Traefik CSP change.
1. Confirm the weekly/push/PR security workflow runs as expected in GitHub
   Actions.
1. Let CI perform full flake and host validation when local `nix-secrets` access
   is unavailable.
1. Review live Trigger.dev access behavior after deployment to ensure only the
   intended email regex can authenticate.

______________________________________________________________________

## Files changed

- `.github/workflows/security-audit.yml`
- `hosts/blizzard/security/traefik.nix`
- `lib/traefik.nix`
- `modules/core/roles.nix`
- `modules/services/trigger.nix`
- `modules/virtualisation/microvm-base.nix`
- `vms/vm-registry.nix`
