# Model public HTTP publication as instance intent

Standard MicroVM public HTTP publication is an explicit, instance-local intent
containing one hostname label and one validated compatibility policy. The host
module derives the registry target and renders Cloudflare Tunnel and Traefik
configuration together; raw port forwarding and bespoke routes remain separate.
We chose this restrictive interface over provider-specific passthrough because
it prevents partial publication, keeps security policy centralized, and makes
the standard path deep enough to hide its two adapter implementations.
