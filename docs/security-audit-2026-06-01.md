# Static Security Audit — 2026-06-01

This report captures a source-guided static security audit of the
`telometto/nix-config` NixOS flake on branch
`migrate/migrate-from-master-to-stable`.

The audit did **not** inspect private secret material, run active network tests,
or attempt exploitation. Full flake evaluation is CI-only in environments that
do not have SSH access to the private `nix-secrets` input.

______________________________________________________________________

## Executive summary

No critical source-level vulnerabilities were confirmed in this pass. The repo
has a strong security baseline: OpenSSH hardening is centralized, SOPS secrets
are bridged as runtime paths, MicroVMs use a restricted baseline, and Traefik is
fronted by CrowdSec on Blizzard.

Remediation batches applied after the initial audit:

- Common local secret files are now ignored.
- Gitleaks now runs in history-aware redacted mode.
- Matrix/Plex-family header exceptions are documented in source.
- The Cloudflare Access IP updater now preserves existing policy constraints
  while rotating the managed IP rule.

The most important remaining follow-ups are:

1. Tighten Traefik CSP defaults and document compatibility exceptions.
1. Add lightweight assertions/checks for role exclusivity and MicroVM registry
   drift.

______________________________________________________________________

## Scope and validation

### Reviewed areas

- SOPS declarations and `sys.secrets.*` consumers.
- Traefik, Cloudflare Tunnel, CrowdSec, and browser security headers.
- MicroVM registry, wired outputs, NAT/bridge exposure, and VM hardening.
- SSH, sudo/wheel, AppArmor, PAM, and host role defaults.
- GitHub Actions security workflow, redaction, and secret scanning.
- Selected service modules with sensitive runtime configuration.

### Local checks performed

| Check | Result |
|------|--------|
| Redacted Gitleaks working-tree scan | Passed; no leaks reported in ~1.13 MB scanned source |
| Redacted Gitleaks history scan | Passed; 8,448 commits and ~6.02 MB scanned |
| Permissive header inventory | Found CSP/CORS compatibility exceptions and permissive defaults |
| Firewall/exposure inventory | Found expected host/VM service exposure points for manual review |
| SSH/root login inventory | No tracked Nix source enabling SSH password auth or root login |
| `sys.secrets.*` consumer inventory | Collected consumers for SOPS bridge review |
| MicroVM allocation parser | 26 registry entries, 25 wired outputs, no current CID/MAC/IP/port duplicates |
| Cloudflare updater parse/JQ fixture | Passed; unmanaged `include`, `exclude`, and `require` policy rules preserved |

### Limitations

- `nix flake check`, host `nix eval`, and host builds were not used as proof
  because this workspace may not have the private `nix-secrets` SSH key.
- Runtime behavior such as CrowdSec parser health, Cloudflare Access policy
  state, Secure Boot, TPM2, and MicroVM network reachability still require CI or
  live-host validation.
- The working tree already contained unrelated uncommitted changes before this
  report was added.

______________________________________________________________________

## Findings

Severity follows the repository's OWASP-aligned model:

- **Critical** — exploitable or likely secret exposure; fix before merge.
- **Important** — significant risk; fix in the same sprint.
- **Suggestion** — defense-in-depth or drift prevention.

### F-001 — CI secret scanning skipped Git history

**Severity:** Important\
**Category:** OWASP A03 Software Supply Chain Failures, A04 Cryptographic
Failures\
**Status:** Remediated in this change set\
**Confidence:** High

The initial audit found that the scheduled security audit checked out full
history but invoked Gitleaks with `--no-git`, which scanned the working tree
instead of commit history. The workflow now runs history-aware Gitleaks with
redacted output.

Evidence:

- `.github/workflows/security-audit.yml:23` sets `fetch-depth: 0`.
- `.github/workflows/security-audit.yml` now runs
  `nix run nixpkgs#gitleaks -- detect --redact --verbose`.

Impact if regressed:

- A secret committed and later removed can remain in history without being
  reported by this workflow.
- The full-history checkout suggests historical scanning was intended, but the
  scanner mode disables it.

Remediation status:

1. `--no-git` was removed from the scheduled workflow.
1. `--redact` was added to reduce accidental disclosure in logs.
1. A separate working-tree scan can still be added later if generated or
   untracked files become relevant to this workflow.

Validation:

- Re-run the workflow and verify it scans commits, not just files in the
  checkout.

### F-002 — Default and service CSP policies permit inline/eval scripts

**Severity:** Important\
**Category:** OWASP A02 Security Misconfiguration, A05 Injection/XSS\
**Confidence:** High

The central Traefik security header helper and several service-specific
middlewares allow `'unsafe-inline'` and `'unsafe-eval'`. A few compatibility
middlewares disable CSP entirely.

Evidence:

- `lib/traefik.nix:4` sets `defaultCsp` with `'unsafe-inline'` and
  `'unsafe-eval'`.
- `modules/services/traefik.nix:170` defines the same permissive default in the
  older service module path.
- `hosts/blizzard/security/traefik.nix:55` defines `plexCsp` with inline/eval
  script allowances.
- `hosts/blizzard/security/traefik.nix:128` defines `lingarr-headers` with
  inline/eval allowances.
- `hosts/blizzard/security/traefik.nix:150`, `:154`, and `:166` disable CSP for
  selected services.
- `modules/services/tautulli.nix:64` uses an inline/eval-compatible Plex CSP.

Impact:

- CSP provides less protection if an exposed app develops an XSS bug.
- Shared defaults can silently propagate weak policy to future services.

Context:

- Some services, especially Plex-adjacent apps or remote browser UIs, may need
  relaxed policies. Those exceptions should be explicit and reviewed rather than
  inherited from the default helper.

Remediation:

1. Change the shared default to a strict baseline without inline/eval.
1. Create named compatibility middlewares for services that require relaxed CSP.
1. Add comments explaining each exception's service constraint and review date.
1. Consider a report-only rollout before enforcing stricter policies.

Validation:

- Use browser developer tools or response-header checks for each public route.
- Verify Plex/OAuth flows and remote browser services still function where
  exceptions are retained.

### F-003 — Cloudflare Access IP updater can clear existing policy rules

**Severity:** Important\
**Category:** OWASP A01 Broken Access Control, A06 Insecure Design\
**Status:** Remediated in this change set\
**Confidence:** High

The initial audit found that the Cloudflare Access updater fetched the current
policy, but only preserved `name`, `decision`, and `precedence`. It replaced
`include` with the current IP and set `exclude` and `require` to empty arrays.
The updater now preserves existing `exclude` and `require` arrays, keeps
unmanaged `include` rules, and replaces only the previous/current managed IP
include rule.

Evidence:

- `modules/services/cloudflare-access-ip-updater.nix` now derives the current
  and previous IP CIDRs, filters only matching managed IP include entries, and
  emits preserved `exclude` / `require` arrays from the current policy response.

Impact if regressed:

- If this updater targets a policy that already has identity, group, MFA,
  country, device posture, or other `require`/`exclude` constraints, those
  constraints can be removed on the next timer run.
- A reusable bypass policy can become easier to misuse if assumptions are not
  enforced in code.

Remediation status:

1. Existing `exclude` and `require` values are preserved.
1. Unmanaged `include` values are preserved.
1. The previous managed IP include is removed using the service state file, and
   the current managed IP include is inserted.

Validation:

- `nix-instantiate --parse modules/services/cloudflare-access-ip-updater.nix`
  passed.
- A local jq fixture confirmed the updater removes the previous managed IP,
  inserts the current managed IP, and preserves unrelated `include`, `exclude`,
  and `require` rules.
- Test against a non-production Cloudflare Access policy with pre-existing
  `require` and `exclude` conditions.

### F-004 — `.gitignore` does not cover common local secret files

**Severity:** Important\
**Category:** OWASP A04 Cryptographic Failures\
**Status:** Remediated in this change set\
**Confidence:** High

The initial audit found that `.gitignore` only ignored the private secrets
checkout, `vars/`, and Nix build results. Common local secret-file patterns are
now ignored.

Evidence:

- `.gitignore` now covers `.env`, `.env.local`, `.env.*.local`, `*.key`,
  `*.pem`, and `*.crt` in addition to `nix-secrets/`, `vars/`, and `result`.

Impact if regressed:

- Common local files such as `.env`, `.env.local`, `.env.*.local`, `*.key`,
  `*.pem`, and `*.crt` can be accidentally staged.
- Gitleaks reduces blast radius but should not be the first line of defense.

Remediation status:

- Ignore patterns for common local secret and private-key material were added.

Validation:

- Verify `git check-ignore` catches the new patterns.

### F-005 — Desktop/server role exclusivity is not enforced

**Severity:** Suggestion\
**Category:** OWASP A06 Insecure Design\
**Confidence:** High

The role module exposes independent booleans for desktop and server roles, but
there is no assertion preventing both from being enabled on one host.

Evidence:

- `modules/core/roles.nix:3` defines `options.sys.role` with separate
  `desktop.enable` and `server.enable` toggles.
- `modules/role-desktop.nix` and `modules/role-server.nix` both enable SSH,
  Tailscale, networking, and other broad host defaults.

Impact:

- Accidental dual-role enablement can merge conflicting service posture and
  firewall defaults.

Remediation:

- Add an assertion that at most one role is enabled, or migrate to a role enum
  such as `"desktop" | "server" | "none"`.

Validation:

- Add a negative evaluation test in CI if feasible.

### F-006 — MicroVM registry drift is documented but not enforced

**Severity:** Suggestion\
**Category:** OWASP A06 Insecure Design, A02 Security Misconfiguration\
**Confidence:** High

The current registry values are unique, but the registry has one entry that is
not wired as a flake output: `flaresolverr`.

Evidence:

- Static parser result: 26 registry entries, 25 wired VM outputs.
- Static parser result: no current duplicate CID, MAC, IP, or port values.
- `vms/vm-registry.nix:191` defines `flaresolverr`.
- `vms/flake-microvms.nix:56-184` wires 25 `*-vm` outputs and omits
  `flaresolverr-vm`.
- `modules/virtualisation/microvm-base.nix:463-468` validates duplicate
  forwarded ports and Cloudflare ingress hosts, but not registry CID/MAC/IP/port
  uniqueness.

Impact:

- Future registry edits can introduce subtle network collisions.
- Registry/output drift can make docs, host enablement, and service routing
  point to different deployment realities.

Remediation:

1. Add a registry validation script or Nix assertion for CID, MAC, IP, and port
   uniqueness.
1. Add an explicit allowlist for intentionally embedded services such as
   `flaresolverr`.
1. Decide whether `flaresolverr` should be a standalone VM, embedded service, or
   removed scaffold.

Validation:

- Run the validator in CI without requiring private secret evaluation.

### F-007 — Matrix CORS/CSP exception needs an explicit security contract

**Severity:** Suggestion\
**Category:** OWASP A02 Security Misconfiguration\
**Status:** Partially remediated in this change set\
**Confidence:** Medium

The Matrix middleware disables CSP and allows wildcard CORS with authorization
headers. This may be required for Matrix client compatibility, but it should be
documented as a protocol-specific exception. Source comments now mark the
Matrix middleware as Matrix-only and warn against reuse outside Matrix routes.

Evidence:

- `hosts/blizzard/security/traefik.nix:166` sets `csp = null` for
  `matrix-headers`.
- `hosts/blizzard/security/traefik.nix:168` sets
  `Access-Control-Allow-Origin = "*"`.
- `hosts/blizzard/security/traefik.nix:171` allows the `Authorization` header.

Impact:

- Future maintainers may copy the Matrix headers to non-Matrix services.
- Broad CORS plus token-bearing APIs increases the importance of client-side
  token handling and XSS prevention in Matrix clients.

Remediation:

1. Document that these headers are Matrix-only and should not be reused.
1. Link to the Matrix compatibility requirement or connectivity-test behavior.
1. Consider a dedicated middleware name that includes `matrix-only`.

Validation:

- Verify the Matrix federation/client checks still pass after any tightening.

### F-008 — CrowdSec console sharing should be an explicit data-sharing choice

**Severity:** Suggestion\
**Category:** OWASP A09 Security Logging and Alerting Failures, Privacy\
**Confidence:** Medium

CrowdSec console sharing is enabled for manual, custom, tainted, and contextual
data, with console management enabled.

Evidence:

- `hosts/blizzard/security/crowdsec.nix:24-28` enables
  `share_manual_decisions`, `share_custom`, `share_tainted`, `share_context`,
  and `console_management`.

Impact:

- Shared security telemetry can include operational context such as target host,
  URI, method, status, and user agent, depending on parser output.

Remediation:

- Document why console sharing is enabled and what data classes are acceptable.
- Revisit the setting if logs begin containing sensitive routes or identifiers.

Validation:

- Review CrowdSec console data samples on the live host.

______________________________________________________________________

## Verified strengths

- OpenSSH hardening is centralized: `PasswordAuthentication = false`,
  `PermitRootLogin = "no"`, and `X11Forwarding = false` are enforced in
  `modules/security/ssh-hardening.nix` and defaulted in
  `modules/services/openssh.nix`.
- Static grep found no tracked Nix source enabling SSH password authentication
  or root login.
- `vms/base.nix` disables SSH root/password login, turns on AppArmor, restricts
  core dumps and kernel pointer exposure, and uses a closed default firewall.
- Matrix URL previews blacklist private, loopback, link-local, documentation,
  and multicast ranges in `modules/services/matrix-synapse.nix`.
- SOPS secrets are declared conditionally in `modules/core/sops.nix`, avoiding
  dangling secret requirements for disabled services.
- Traefik's CrowdSec bouncer key is copied into a `0750` runtime directory
  before use, avoiding broad access to the SOPS source path.
- `modules/virtualisation/microvm-base.nix` already validates unknown exposed
  VMs, unknown autostart entries, missing port-forward IPs, duplicate forwarded
  ports, duplicate Cloudflare ingress hosts, and Cloudflare Tunnel enablement.

______________________________________________________________________

## Remediation roadmap

### Immediate quick wins

1. [x] Update `.gitignore` for common local secret/key files.
1. [x] Change the CI Gitleaks command to scan history and use redacted output.
1. [x] Document Matrix and Plex-family header exceptions in the source.

### Next sprint

1. [x] Refactor the Cloudflare Access updater to preserve unmanaged policy fields.
1. Add role exclusivity assertion or migrate to a role enum.
1. Add MicroVM registry/output consistency validation.
1. Split strict Traefik defaults from named compatibility middlewares.

### Later / live validation

1. Validate CrowdSec parser health and bouncer decisions on Blizzard.
1. Verify Cloudflare Access policy state after updater runs.
1. Test MicroVM bridge reachability and VM-to-host boundaries.
1. Review Secure Boot, TPM2, and AppArmor behavior on actual hosts.

______________________________________________________________________

## Files reviewed

- `.gitignore`
- `.github/workflows/security-audit.yml`
- `.github/scripts/redact-secrets.sh`
- `lib/traefik.nix`
- `modules/core/roles.nix`
- `modules/core/security.nix`
- `modules/core/sops.nix`
- `modules/core/users.nix`
- `modules/security/secrets.nix`
- `modules/security/ssh-hardening.nix`
- `modules/services/cloudflare-access-ip-updater.nix`
- `modules/services/cloudflared.nix`
- `modules/services/gitea.nix`
- `modules/services/matrix-authentication-service.nix`
- `modules/services/matrix-synapse.nix`
- `modules/services/openssh.nix`
- `modules/services/tautulli.nix`
- `modules/services/traefik.nix`
- `modules/virtualisation/microvm-base.nix`
- `hosts/blizzard/security/crowdsec.nix`
- `hosts/blizzard/security/traefik.nix`
- `hosts/blizzard/services/cloudflared.nix`
- `hosts/blizzard/virtualisation/microvms.nix`
- `vms/base.nix`
- `vms/flake-microvms.nix`
- `vms/gitea.nix`
- `vms/paperless.nix`
- `vms/firefly.nix`
- `vms/vm-registry.nix`
