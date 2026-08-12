# Service mail architecture

Status: approved design; planning artifact only

Last reviewed: 2026-08-03

This document defines how self-hosted services send and receive email without
turning one mail credential or one daemon into an infrastructure-wide trust
boundary. It records the provider split, service contracts, security controls,
and the ownership boundaries for later implementation pull requests.

No provider credentials, DNS record values, mailbox passwords, SMTP tokens, or
Bridge credentials belong in this repository. Secret material remains in the
private `nix-secrets` flake or the relevant provider console.

## Decision summary

These are repository design decisions, not claims about provider behavior:

1. Proton Mail owns the root mail domain. Human addresses, stable service
   identities, and all recovery addresses use `@<domain>`.
1. SimpleLogin owns only `alias.<domain>`. It is for privacy aliases that
   forward to a real mailbox, not for service identities or recovery.
1. Every service that sends mail submits directly to Proton using its own
   permanent root-domain address and its own SMTP token.
1. There is no shared outbound relay and no dedicated SMTP VM. A failed or
   compromised service must not require rotating every other service's sender
   credential.
1. Proton Mail Bridge is used only where a service must read inbound mail over
   IMAP. It is co-located with that service and bound to the local service
   boundary. Paperless is the only current Bridge consumer.
1. Bridge runs in split-address mode for automated ingestion. A service sees
   only the address assigned to it, even if several addresses share the same
   Proton account.
1. Multiple service addresses may initially live under one Proton user.
   Separate Proton users are a later isolation option only when the additional
   blast-radius reduction justifies the account, plan, and operational cost.
1. Inbound document automation is default-deny. Paperless consumes only mail
   matching explicit sender and attachment rules; unmatched mail remains
   unprocessed for manual review.

## Current repository snapshot

The following are observations from this repository, not statements that the
approved target has already been deployed:

- [The Matrix VM](../vms/matrix-synapse.nix) injects one
  `protonmail/smtp_token` into both Synapse and Matrix Authentication Service
  (MAS). Synapse has `enable_notifs = false`, while MAS is configured to send
  as `matrix@<domain>` through `smtp.protonmail.ch:587` with STARTTLS.
- The same Matrix file enables local MAS passwords and password registration,
  but does not set `account.password_recovery_enabled`. MAS documents email
  password recovery as disabled by default, so the current configuration does
  not provide that recovery path. See the upstream
  [MAS account configuration reference](https://element-hq.github.io/matrix-authentication-service/reference/configuration.html#account).
- [The Pocket ID VM](../vms/pocket-id.nix) has no SMTP settings. The current
  [Pocket ID operations guide](pocket-id.md) consequently documents email
  verification, email recovery, and login notifications as unavailable.
- [The Paperless VM](../vms/paperless.nix) includes the repository's custom
  headless [Proton Mail Bridge module](../modules/services/protonmail-bridge.nix)
  and persistent Bridge state. It does not yet declare a Paperless mail account
  or mail-import rules. The Blizzard service selection currently leaves
  Paperless disabled in
  [hosts/blizzard/services/productivity.nix](../hosts/blizzard/services/productivity.nix).
- The Bridge module runs as a dedicated system user, keeps its state under a
  mode-`0700` directory, and applies a basic systemd sandbox. Those controls
  reduce local exposure but do not isolate multiple consumers from a shared
  Bridge login; this design therefore keeps each Bridge beside its only
  consumer.

## Provider constraints

These facts come from provider-owned documentation and constrain the design:

- Proton SMTP submission is send-only; receiving through a third-party client
  requires Bridge. Proton documents `smtp.protonmail.ch`, port `587`, STARTTLS,
  and a special SMTP token rather than a Proton account or mailbox password.
  SMTP submission is available for paid Proton Mail plans with custom-domain
  addresses. See [Proton SMTP submission](https://proton.me/support/smtp-submission).
- Proton recommends a separate SMTP token for every client so one client's
  permission can be revoked without affecting the others. A token is paired
  with an active custom-domain address, is shown only when created, and its
  provider record exposes its name, address, creation time, and last-use time.
  See [Proton SMTP submission](https://proton.me/support/smtp-submission).
- Proton advises installing a replacement token in the client before deleting
  the old token. Deleting a token immediately stops clients using it from
  sending. See [Proton SMTP submission](https://proton.me/support/smtp-submission#how-to-disable-smtp).
- Bridge creates local IMAP and SMTP endpoints because clients cannot directly
  read Proton's encrypted mailbox data. Proton says those endpoints are
  accessible only to applications on the same device, which aligns with a
  co-located service design. See
  [Why you need Proton Mail Bridge](https://proton.me/support/why-you-need-bridge).
- Bridge combined mode presents all addresses through one mailbox, while split
  mode presents each address separately and supplies separate connection
  details. See
  [Proton Bridge address modes](https://proton.me/support/difference-combined-addresses-mode-split-addresses-mode).
- Proton does not permit the same custom domain to be active for both Proton
  Mail and Proton Pass hide-my-email aliases. Using a dedicated SimpleLogin
  subdomain avoids competing for the root-domain mail routing. See
  [Proton hide-my-email custom domains](https://proton.me/support/pass-email-alias#create-aliases-with-a-custom-domain-address).
- SimpleLogin documents adding a subdomain as its own custom-domain object with
  verification TXT and dedicated MX records, plus recommended SPF, DKIM, and
  DMARC records. See
  [SimpleLogin custom-subdomain setup](https://simplelogin.io/docs/custom-domain/registrars/namecheap/namecheap-subdomain/).

## Domain and address ownership

| Namespace | Provider | Intended identities | Prohibited uses |
|---|---|---|---|
| `@<domain>` | Proton Mail | Human mailboxes, one stable address per service, password and account recovery | Disposable or per-site privacy aliases |
| `@alias.<domain>` | SimpleLogin | Per-site privacy aliases forwarded to a controlled Proton mailbox | SMTP service identities, infrastructure alerts, or recovery authority |

The separation is deliberate. A SimpleLogin outage, alias deletion, or privacy
alias compromise must not remove the recovery path for Pocket ID, Matrix, or
another service. A service address remains stable while its SMTP token can be
rotated or revoked independently.

### DNS contract

Provider consoles remain the source of truth for exact DNS values; copy values
from the active tenant rather than from this document.

For the root domain:

1. Keep the root-domain MX records on Proton.
1. Create every required root-domain recipient in Proton before changing MX
   records. Proton warns that mail to nonexistent addresses will not be
   delivered after its MX records become authoritative. See
   [Proton custom-domain setup](https://proton.me/support/custom-domain#step-4-update-mx-records).
1. Publish the Proton-supplied SPF, all supplied DKIM selectors, and DMARC.
   Proton documents that the domain must have only one SPF record and recommends
   `p=quarantine` for most domains. Move to an enforcing DMARC policy only after
   the actual senders pass validation. See
   [Proton custom-domain authentication records](https://proton.me/support/custom-domain#step-5-configure-spf-dkim-and-dmarc-records).

For `alias.<domain>`:

1. Add the full subdomain, not the root domain, to SimpleLogin.
1. Publish SimpleLogin's current verification and MX values at that subdomain.
1. Publish the SimpleLogin-supplied SPF, DKIM, and DMARC records at the
   subdomain so the root-domain Proton records are not replaced. SimpleLogin's
   official setup describes the separate TXT, MX, SPF, DKIM, and DMARC records
   for a subdomain. See
   [SimpleLogin custom-subdomain setup](https://simplelogin.io/docs/custom-domain/registrars/namecheap/namecheap-subdomain/).
1. Verify both namespaces independently: inbound delivery, outbound SPF/DKIM
   alignment, DMARC evaluation, and reply behavior.

Do not merge provider SPF strings by intuition or publish copied example
tokens. Review the effective DNS tree after every mail-provider change and
confirm that root-domain and subdomain MX records remain distinct.

## Outbound submission contract

Every sending service has this contract:

| Property | Requirement |
|---|---|
| Address | Permanent, unique `service@<domain>` address created in Proton |
| Credential | Unique Proton SMTP token named for the service, host, and purpose |
| Storage | SOPS secret in `nix-secrets`; runtime file readable only by the service user |
| Endpoint | `smtp.protonmail.ch:587` with STARTTLS and required transport security |
| Username | The same active custom-domain address paired with the token |
| Envelope and header identity | Use the assigned service address; do not impersonate another service |
| Failure behavior | Fail closed, retain the application action where safe, and expose a send error |
| Revocation | Delete only the affected service token after replacement or incident response |

Direct submission intentionally duplicates a small amount of endpoint
configuration. It avoids a relay VM whose compromise, queue corruption,
certificate failure, or outage would affect every service and whose
authentication policy would need to reproduce Proton's per-client controls.

Proton notes that messages submitted this way appear in the account's Sent
folder and are not end-to-end encrypted during SMTP submission, although they
are stored with Proton's zero-access encryption. Treat the service-to-Proton
connection and message content as normal SMTP trust boundaries. See
[Proton SMTP submission](https://proton.me/support/smtp-submission#how-does-it-work).

## Inbound IMAP contract

Bridge is not the general outbound path. Add it only when a service has an
approved requirement to fetch received mail:

1. Run Bridge inside the same MicroVM as the consuming service.
1. Keep Bridge's IMAP and SMTP listeners on loopback or an equivalently local
   boundary. Do not publish them through the host, Traefik, Tailscale, or the
   MicroVM bridge.
1. Give the Bridge process its own system user and restrictive persistent-state
   permissions. Its login, local IMAP password, cache, and keychain state are
   credentials or credential-adjacent data.
1. Select split-address mode and configure the consumer with only its service
   address connection details.
1. Use direct Proton SMTP submission for outbound workflows even when Bridge is
   present. This preserves per-service token revocation and keeps Bridge scoped
   to inbound IMAP.
1. Do not share one Bridge daemon across MicroVMs. A new inbound consumer gets a
   co-located instance after an explicit review.

Bridge is officially tested with a limited set of desktop clients; Proton says
other IMAP/SMTP clients may work but are not guaranteed. Paperless is therefore
a compatibility-tested integration, not an assumed supported-client pairing.
See [clients supported by Proton Mail Bridge](https://proton.me/support/clients-supported-bridge).

### Paperless ingestion policy

Paperless mail automation is an untrusted-document ingress path. The mailbox
receiving a message is not sufficient authorization to import its attachments.

1. Assign Paperless a dedicated root-domain address and expose only that
   address through Bridge split mode.
1. Create explicit mail rules for known sender addresses or narrowly approved
   sender domains. Avoid a catch-all rule.
1. Restrict attachments with explicit filename patterns and approved document
   formats. Start with the smallest required set and expand only after a real
   rejected document is reviewed.
1. Import only when both the sender rule and attachment rule match.
1. Leave unmatched or attachment-free mail unprocessed in a dedicated review
   folder or mailbox view. Do not delete it automatically.
1. Move successfully consumed messages to a distinct processed folder so
   backlog and duplicate-processing behavior are visible.
1. Treat parsing and OCR as hostile-input processing: keep Paperless isolated,
   patched, resource-limited, and backed up; never execute imported content.

Paperless documents that its mail consumer applies account rules, fetches only
matching mail, checks for consumable attachments, and ignores messages that do
not match filters. It also supports attachment filename patterns and post-import
mail actions. See [Paperless email processing](https://docs.paperless-ngx.com/usage/#email-processing).

## Service matrix

The target address names below are non-secret configuration. Confirm address
availability in Proton before implementation.

| Service | Current repository state | Target mail path | Activation gate |
|---|---|---|---|
| Matrix Authentication Service | Configured to send through Proton as `matrix@<domain>` using the generic Matrix SMTP secret; email password recovery is not enabled | Sole Matrix sender; direct Proton submission with a Matrix-only token; enable MAS email password recovery | Existing users have verified recovery addresses; a real password reset completes end to end; login and rollback tests pass |
| Synapse | Receives the same generic SMTP secret, but notifications are disabled | No SMTP configuration or token; MAS owns Matrix account and recovery mail | Removal occurs in the Matrix baseline PR and existing Matrix/MAS flows still pass |
| Pocket ID | SMTP intentionally absent | Direct Proton submission as `pocket-id@<domain>` with a Pocket-ID-only token | Send and follow real initial-access and recovery emails before any new OIDC client cutover |
| Paperless | VM definition includes co-located Bridge; service is disabled and has no mail rules | Inbound through a co-located split-mode Bridge as `paperless@<domain>`; direct Proton submission with a separate token only if outbound workflows are enabled | Bridge compatibility is proven, listeners remain local, and default-deny sender/attachment rules plus manual review are tested |

MAS documents `password_recovery_enabled` as an explicit account setting that
defaults to false and has no effect when password login is disabled. Recovery
must therefore be enabled and exercised while Matrix passwords are still
retained. See the
[MAS account configuration reference](https://element-hq.github.io/matrix-authentication-service/reference/configuration.html#account).

Pocket ID SMTP is a prerequisite for the approved OIDC migration, not part of
the current network-hardening rollout. The sequencing and recovery requirements
remain in the [Pocket ID migration plan](pocket-id-migration-plan.md).

## Credential lifecycle

Apply the repository's [credential lifecycle policy](credential-lifecycle.md):
rotate on compromise, provider expiry, ownership change, or another concrete
risk event rather than on an arbitrary short timer.

### Provision

1. Create and verify the permanent service address in Proton.
1. Generate a uniquely named SMTP token for exactly that address and service.
1. Record non-secret ownership metadata: service, host, address, purpose,
   creation date, and operator. Never record the token value here.
1. Store the token under a service-specific SOPS key in `nix-secrets`; do not
   reuse the existing generic `protonmail/smtp_token` key for new consumers.
1. Expose it as a runtime file owned by the consuming service and restart only
   that service.
1. Send a real functional message and complete the action it protects, such as
   following a recovery link. Confirm the message also appears under the
   expected Proton sender.

### Rotate

1. Generate a second service-specific token without deleting the active token.
1. Update the SOPS value and deploy only the consuming service.
1. Complete an end-to-end send and functional recovery test.
1. Delete the old Proton token and confirm the service continues to send.
1. Roll back to the previous SOPS revision only while the old provider token
   still exists; otherwise create a new token.

This overlap order follows Proton's documented recommendation to switch the
client before deleting the old token. See
[Proton SMTP token replacement](https://proton.me/support/smtp-submission#how-to-disable-smtp).

### Review and revoke

During the regular credential review:

- Reconcile Proton's active-token list with enabled repository consumers.
- Review token creation and last-use metadata for unexpected activity or a
  supposedly active sender that is never used.
- Revoke tokens for disabled or removed services.
- Review recovery and service-address ownership separately from privacy aliases.
- Review Bridge logins, local credentials, state backups, and mailbox rules for
  every inbound consumer.

## Threat model

| Threat | Consequence | Required control | Residual risk |
|---|---|---|---|
| One service leaks its SMTP token | Attacker sends as that service and damages domain reputation | Unique address and token; least-readable runtime file; service-only revocation | Provider and recipient rate limits may react before the operator |
| A shared relay fails or is compromised | All service mail stops or can be forged | No relay; services submit directly to Proton | Proton remains a common external dependency |
| Root-domain recovery mailbox is compromised | Password or identity recovery may be captured | Strong Proton account security, independent administrator recovery, and real recovery tests | Email remains a deliberate recovery authority |
| A privacy alias is deleted or SimpleLogin is unavailable | Mail to that alias is delayed or lost | Never use `alias.<domain>` for service identity or recovery | Privacy-alias correspondence remains provider-dependent |
| Malicious mail reaches Paperless | Hostile attachment is parsed, stored, or used to exhaust resources | Explicit sender plus attachment rules, no catch-all, quarantine/unprocessed default, service isolation | Approved senders can be compromised and document parsers can contain vulnerabilities |
| Bridge state or local password is exposed | Attacker may read the service mailbox | Co-location, local-only listeners, dedicated user, restrictive state permissions, separate consumer instance | Addresses under one Proton user still share an upstream account boundary |
| Root and alias DNS records are mixed | Mail is misrouted or authentication fails | Separate root/subdomain ownership, provider-console values, effective-DNS verification | DNS and both providers remain external control planes |
| A token is rotated incorrectly | Service recovery or notifications stop | Overlap old and new tokens; functional test before revocation; scoped rollback | Provider-side deletion cannot be undone |

Separate Proton users become warranted when the residual shared-account risk is
larger than the additional cost and operational burden—for example, when an
inbound mailbox contains substantially more sensitive data, has a different
administrator, or needs independent account recovery. That decision requires a
new review; it is not necessary merely because addresses are unique.

## Operations and observability

Mail health must describe user-visible capability, not only whether a TCP
connection can be opened.

### Signals

- Alert on sustained service log errors for SMTP authentication, TLS,
  submission, template generation, or provider rejection.
- Alert when the Paperless Bridge unit or mail-fetch task is repeatedly failing.
  Track the oldest unprocessed message or review-folder backlog once a reliable
  metric is available.
- Treat a lost Bridge-to-Proton connection as a mail-path failure, not merely a
  degraded cache: Proton documents that Bridge shuts down its local IMAP and
  SMTP endpoints when that upstream connection is interrupted. See
  [Bridge connection failures](https://proton.me/support/how-to-resolve-connection-issues-in-bridge).
- Record the time and result of the last real recovery exercise for MAS and
  Pocket ID. Do not create a synthetic Pocket ID user solely for continuous
  email testing.
- Review Proton token last-use timestamps during credential reviews. They are a
  provider-console audit signal, not proof that a recipient received or used a
  message. Proton documents this metadata in its
  [SMTP token interface](https://proton.me/support/smtp-submission#how-to-set-up-smtp).
- Monitor SPF, DKIM, and DMARC results through received-message headers and
  DMARC aggregate reports. Treat a sudden alignment regression as a deployment
  or DNS incident.
- Correlate failures with the official [Proton service status](https://status.proton.me/),
  but do not treat provider status as proof that local service-to-provider or
  provider-to-recipient delivery works.

### Dashboard and alerts

Later implementation should expose a small declarative set of mail-capability
signals to the existing Prometheus/Grafana stack:

- service send failures and last successful functional exercise;
- Bridge unit state, restart count, and Paperless mail-fetch failures;
- Paperless unprocessed/review backlog when it can be measured reliably;
- active incidents and the service/address they affect.

Use Pushover for sustained actionable failures and their resolution, not for
every individual retry. A dashboard may show the last manual recovery exercise,
but it must not turn a manually recorded timestamp into a claim of continuous
delivery health.

### Incident response

For suspected outbound-token compromise:

1. Identify the address and token from the service-specific mapping.
1. Stop or isolate the affected service if it may continue leaking the token.
1. Delete only that token in Proton and create a replacement.
1. Update the matching SOPS key, deploy the service, and test delivery.
1. Review Proton Sent mail, service logs, token last-use metadata, DMARC reports,
   and recipient reports for abuse.
1. Escalate to root-domain or account credential rotation only if evidence
   crosses the service-token boundary.

For inbound Paperless compromise or malicious input, stop mail fetching before
changing mailbox rules, preserve the message and task evidence, isolate the
document, and review whether the approved sender account or Bridge state was
compromised.

## Pull-request boundaries and rollout

This document is intentionally separate from the active MicroVM networking
hardening branch. It does not authorize provider, DNS, secret, or runtime
changes.

| Change set | Owns | Does not own |
|---|---|---|
| Service mail architecture | This contract, root/subdomain provider split, address/token inventory, Bridge isolation requirements, and shared monitoring vocabulary | Matrix ingress, OIDC clients, password removal, or network-policy enforcement |
| Matrix baseline hardening | Make MAS the sole Matrix sender, replace the generic token with a Matrix-only secret, remove Synapse SMTP, enable and test MAS password recovery | Pocket ID upstream OIDC or removal of existing Matrix passwords |
| Pocket ID OIDC migration | Configure Pocket ID's dedicated sender, pass real initial-access/recovery mail gates, then follow the approved service order with Matrix last | Central relay or reuse of the Matrix token |
| Paperless activation | Configure co-located Bridge split mode, local-only access, explicit mail rules, review workflow, and any separately justified outbound sender | Shared Bridge VM or catch-all document ingestion |

Runtime work follows the roadmap:

1. Finish and audit `security/microvm-networking-hardening`; enforce and merge
   only after its approved observation gate.
1. Prepare this mail architecture and provider inventory independently.
1. Implement Matrix baseline hardening in its own change set, then observe seven
   clean days before another Matrix runtime change.
1. Implement Pocket ID SMTP and recovery gates before activating additional
   OIDC clients.
1. Migrate Matrix to Pocket ID last, retaining Matrix passwords until account
   links, recovery, client compatibility, and a separate removal approval are
   complete.

## Implementation checklist

- [ ] Inventory existing Proton users, root-domain addresses, SMTP tokens, and
  SimpleLogin domains without copying secret values into an issue or commit.
- [ ] Reserve permanent `matrix@<domain>`, `pocket-id@<domain>`, and
  `paperless@<domain>` addresses, adjusting names once before deployment if an
  address is unavailable.
- [ ] Confirm root-domain Proton MX/SPF/DKIM/DMARC and subdomain SimpleLogin
  TXT/MX/SPF/DKIM/DMARC independently.
- [ ] Create one Proton token per sending service and matching service-specific
  SOPS keys.
- [ ] Complete the Matrix baseline mail changes and real MAS password-recovery
  test.
- [ ] Configure and test Pocket ID initial-access and recovery mail before the
  next OIDC activation.
- [ ] Before enabling Paperless, validate Bridge split mode with the pinned
  package, keep its listeners local, and test positive and negative mail rules.
- [ ] Add mail-capability panels and sustained alerts without continuous
  synthetic recovery users.
- [ ] Record rollback steps and the last successful functional mail exercise for
  each activated service.

## Primary external references

- [Proton SMTP submission](https://proton.me/support/smtp-submission)
- [Proton Mail custom-domain setup](https://proton.me/support/custom-domain)
- [Why Proton Mail Bridge is required for IMAP](https://proton.me/support/why-you-need-bridge)
- [Proton Bridge combined and split address modes](https://proton.me/support/difference-combined-addresses-mode-split-addresses-mode)
- [Proton Bridge supported clients](https://proton.me/support/clients-supported-bridge)
- [Proton hide-my-email custom domains](https://proton.me/support/pass-email-alias#create-aliases-with-a-custom-domain-address)
- [SimpleLogin custom-subdomain setup](https://simplelogin.io/docs/custom-domain/registrars/namecheap/namecheap-subdomain/)
- [MAS configuration reference](https://element-hq.github.io/matrix-authentication-service/reference/configuration.html)
- [Paperless email processing](https://docs.paperless-ngx.com/usage/#email-processing)
