# Mealie VM Design

**Date:** 2026-04-28
**Branch:** dev-vm-mealie

## Summary

Add a MicroVM for [Mealie](https://mealie.io) (recipe manager and meal planner, v3.12.0) following the established VM pattern in this repo. The VM is internet-exposed via Cloudflare Tunnel + Traefik, using Mealie's native NixOS module with PostgreSQL and sops-nix for secrets.

______________________________________________________________________

## Decisions

| Question | Decision |
|----------|----------|
| Database | PostgreSQL (local, `database.createLocally = true`) |
| Auth | Built-in Mealie auth; public signup disabled; TLS via Cloudflare Tunnel |
| Subdomain | `recipes.<public-domain>` |
| Module structure | Full `sys.services.mealie` wrapper (Option B) |

______________________________________________________________________

## Registry Entry (`vms/vm-registry.nix`)

```nix
mealie = {
  name    = "mealie";
  cid     = 125;
  mac     = "02:00:00:00:00:1A";
  ip      = "10.100.0.71";
  port    = 11071;
  mem     = 1024;
  vcpu    = 1;
};
```

Gateway: `10.100.0.1` (direct-routed, not VPN-routed).

______________________________________________________________________

## Volumes

| Image | Mount | Size |
|-------|-------|------|
| `mealie-state.img` | `/var/lib/mealie` | 51200 MiB (50 GB) |
| `postgresql-state.img` | `/var/lib/postgresql` | 10240 MiB (10 GB) |

(Plus the standard `persist.img` at 64 MiB appended by `mkMicrovmConfig`.)

______________________________________________________________________

## Service Module (`modules/services/mealie.nix`)

Options under `sys.services.mealie`:

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `enable` | bool | false | mkEnableOption |
| `port` | port | 9000 | Mealie upstream default |
| `listenAddress` | str | `"127.0.0.1"` | nginx fronts on external port |
| `database.createLocally` | bool | true | Local PostgreSQL |
| `credentialsFile` | nullOr path | null | sops secret path; EnvironmentFile format |
| `settings` | attrs | {} | Passthrough to `services.mealie.settings` |
| `reverseProxy` | — | — | `traefikLib.mkReverseProxyOptions` |

Config block wires:

- `services.mealie` (upstream NixOS module)
- `services.postgresql` with init script creating `mealie` role + database
- `services.traefik.dynamic.files.mealie` via `mkTraefikDynamicConfig`
- Security settings baked in: `ALLOW_SIGNUP = "false"`, `BASE_URL` from `reverseProxy.domain`

______________________________________________________________________

## VM File (`vms/mealie.nix`)

Imports:

- `./base.nix`
- `../modules/services/mealie.nix`
- `inputs.sops-nix.nixosModules.sops`
- `mkMicrovmConfig` with the two volumes above

sops:

- `age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ]`
- Secret: `mealie/secret_key` (owner `mealie:mealie`, mode `0440`)

systemd:

- `tmpfiles.rules` creating `/var/lib/mealie` (mealie:mealie 0700) and `/var/lib/postgresql` (postgres:postgres 0700)
- `mealie.service` `after`/`requires` on `sops-install-secrets.service`

Networking:

- `networking.firewall.allowedTCPPorts = [ reg.port ]`

nginx:

- VirtualHost on `0.0.0.0:reg.port` → `http://127.0.0.1:9000`
- `proxyWebsockets = true`
- `client_max_body_size 100M` (recipe images)
- Standard proxy headers (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto https`)

`sys.services.mealie`:

- `enable = true`
- `reverseProxy.domain = "recipes.${VARS.domains.public}"`

______________________________________________________________________

## Flake Integration (`vms/flake-microvms.nix`)

```nix
mealie-vm = mkMicrovm [
  microvmModule
  sopsModule
  ./mealie.nix
];
```

______________________________________________________________________

## Host Integration (`hosts/blizzard/virtualisation/microvms.nix`)

```nix
mealie = {
  enable = true;
  portForwards = [ (mkPortForward "tcp" 11071 null) ];
  ingressHosts = [ "recipes" ];
  reverseProxy = {
    subdomain = "recipes";
    url = vmUrl "mealie";
    middlewares = [ "security-headers" "crowdsec" ];
  };
};
```

______________________________________________________________________

## Security Considerations

- **No public signup** — `ALLOW_SIGNUP = "false"` baked into the service module
- **TLS** — enforced end-to-end via Cloudflare Tunnel; Traefik receives HTTPS from CF and proxies to the VM over the internal bridge
- **Secret key** — injected via sops-nix `credentialsFile`; never in the Nix store
- **Firewall** — only `reg.port` (11071) open on the VM; Mealie's internal port (9000) is bound to `127.0.0.1` only
- **AppArmor** — inherited from `base.nix`
- **sysctl hardening** — inherited from `base.nix`
- **crowdsec middleware** — applied at Traefik layer for rate-limiting/banning
- **security-headers middleware** — applied at Traefik layer (X-Frame-Options, CSP, etc.)

______________________________________________________________________

## sops-nix Bootstrap Note

After first boot, retrieve the VM's age key:

```bash
ssh admin@10.100.0.71 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
```

Add it to `.sops.yaml`, encrypt `mealie/secret_key`, and re-deploy.
