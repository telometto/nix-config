# Scrutiny Operations

Scrutiny runs on `blizzard`. Its web interface listens on `127.0.0.1:11001`
and is published through the host's existing reverse-proxy and Cloudflare
Tunnel configuration. The collector uses the same local endpoint.

## Configure the InfluxDB token

The token is intentionally kept in the private `nix-secrets` flake:

1. Create an InfluxDB API token with the minimum read/write permissions needed
   for Scrutiny's metrics bucket and organization.
1. Add the token value under the exact SOPS key `scrutiny/token` in the private
   secrets repository.
1. Deploy Blizzard so sops-nix can decrypt the secret. Do not copy the token
   into this repository or into a host module.

When Scrutiny is enabled, sops-nix creates the root-only secret and a root-only
systemd EnvironmentFile containing `SCRUTINY_WEB_INFLUXDB_TOKEN`. The Scrutiny
unit starts after `sops-install-secrets.service` and is restarted when the
token changes.

## Provision and verify

From a checkout with access to the private secrets flake, deploy the host:

```console
sudo nixos-rebuild switch --flake .#blizzard
```

Verify the service without printing the token:

```console
systemctl is-active scrutiny.service
systemctl show scrutiny.service --property=EnvironmentFiles
journalctl -u scrutiny.service -n 50 --no-pager
```

Open the published Scrutiny hostname and confirm that the collector produces
current disk data. The service log should not contain InfluxDB authentication
errors. Use the InfluxDB token audit or usage view, when available, to confirm
that the replacement token is being used.

## Rotate the token

1. Create a replacement InfluxDB token with the same least-privilege access.
1. Replace the value at `scrutiny/token` in the private secrets repository.
1. Deploy Blizzard with the command above. sops-nix queues the Scrutiny unit
   restart before switching the rendered secret, so the running process gets
   the new token.
1. Repeat the service, log, and UI checks above.
1. Revoke the old InfluxDB token after the new token is confirmed healthy.

If the service was stopped during rotation, inspect its logs first. A manual
`systemctl restart scrutiny.service` is only a recovery step after the updated
secret has been deployed; it is not a substitute for updating `scrutiny/token`.
