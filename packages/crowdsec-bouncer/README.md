# Traefik CrowdSec attribution extension

This package applies `attribution.patch` to the hash-pinned upstream v1.4.5
archive and adds `telemetry.go`. Upstream vendored dependencies and license
remain in the output. Blizzard loads the output as a Traefik local plugin.

Keep the patch small and review the enforcement/cache call sites when updating
upstream. Reporting must not change the decision action, block an application
response on its own, or export source IP/path as a metric label. Operational
fail-closed denials must stay separate from attack counts.

`telemetry_test.go` includes a synthetic stream-to-request-to-LAPI regression
and a pure counter/metadata check. The pure check runs in the Nix build; the
socket tests and real Yaegi fixture run outside the build sandbox in CI.

Do not replace the real Traefik fixture with only compiled Go tests: the Yaegi
interpreter requires explicit response-writer methods and native log output.
See [the operations runbook](../../docs/crowdsec-observability.md).
