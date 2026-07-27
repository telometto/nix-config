# Model public HTTP publication as instance intent

Standard MicroVM public HTTP publication is an explicit, instance-local intent
containing one hostname label and one validated compatibility policy. The host
module derives the registry target and renders Cloudflare Tunnel and Traefik
configuration together; raw port forwarding and bespoke routes remain separate.
We chose this restrictive interface over provider-specific passthrough because
it prevents partial publication, keeps security policy centralized, and makes
the standard path deep enough to hide its two adapter implementations.

When a workload also needs a supplemental host or path route, that route must
reuse the managed publication service and be gated by the publication intent.
Matrix follows this pattern: `matrix.<domain>` is a standard publication, while
the root-domain `/.well-known/matrix/` discovery route remains explicit and is
present only while the Matrix publication is enabled.
