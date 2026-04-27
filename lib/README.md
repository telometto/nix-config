## Library Functions

Reusable Nix functions and data shared across the configuration. All four files
are passed into hosts and VMs as `specialArgs` from `flake.nix`.

---

### constants.nix

Shared string constants used throughout the configuration. Loaded once in
`flake.nix` as `consts` and threaded through all hosts and VMs via
`specialArgs`.

**Purpose:** Avoid repeating magic strings (domain suffixes, IDs) in multiple
places.

**Usage pattern:**

```nix
# In any host or VM module that receives specialArgs
{ consts, ... }:
{
  # Build a Tailscale FQDN for a service
  services.nginx.virtualHosts."myservice.${consts.tailscale.suffix}" = { ... };
}
```

**Exported values:**

| Key | Value | Purpose |
|-----|-------|---------|
| `tailscale.suffix` | `"mole-delta.ts.net"` | Tailscale network domain suffix for building service FQDNs |

---

### traefik.nix

Helper functions for generating Traefik dynamic configuration and NixOS option
declarations. Reduces the per-service boilerplate when wiring up reverse-proxy
support.

**Purpose:** Every service module that supports a reverse proxy needs the same
set of options (domain, pathPrefix, cfTunnel, etc.) and the same Traefik
router/service config block. These helpers generate both from a single
descriptor.

**Usage pattern — adding reverse-proxy options to a service module:**

```nix
{ lib, config, pkgs, ... }:
let
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
  cfg = config.sys.services.myservice;
in
{
  options.sys.services.myservice = {
    enable = lib.mkEnableOption "My Service";
  } // traefikLib.mkReverseProxyOptions { name = "myservice"; };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # ... service config ...
    }
    (traefikLib.mkTraefikDynamicConfig {
      name = "myservice";
      cfg = cfg;
      config = config;
      port = 8080;
    })
    { assertions = [ (traefikLib.mkCfTunnelAssertion { name = "myservice"; cfg = cfg; }) ]; }
  ]);
}
```

**Function signatures:**

| Function | Parameters | Returns |
|----------|------------|---------|
| `defaultPermissionsPolicy` | — | `string` — opinionated browser permissions policy header value |
| `defaultCsp` | — | `string` — default Content Security Policy header value |
| `mkSecurityHeaders` | `{ xFrameOptions, xssProtection, referrerPolicy, permissionsPolicy, csp, extraResponseHeaders, requestHeaders }` | Traefik middleware headers attrset. Pass `null` to any param to omit that header. |
| `mkRoutes` | `{ domain, defaultMiddlewares? } routes` | `{ routers, services }` — Traefik router + service config for each route |
| `mkReverseProxyOptions` | `{ name, defaults? }` | NixOS option declarations for `reverseProxy` sub-option |
| `mkTraefikDynamicConfig` | `{ name, cfg, config, port, defaultMiddlewares?, extraDynamicConfig? }` | `lib.mkIf` block generating Traefik router + service config |
| `mkCfTunnelAssertion` | `{ name, cfg }` | NixOS assertion: `cfTunnel.enable` requires `domain` to be set |

**`mkReverseProxyOptions` generated sub-options:**

Each call adds these options under `sys.services.<name>.reverseProxy`:

| Option | Type | Purpose |
|--------|------|---------|
| `enable` | `bool` | Toggle reverse proxy for this service |
| `domain` | `str` (nullable) | FQDN used for the Traefik router rule |
| `pathPrefix` | `str` (nullable) | URL path prefix to match |
| `stripPrefix` | `bool` | Strip the path prefix before forwarding |
| `extraMiddlewares` | `[str]` | Additional Traefik middleware names |
| `cfTunnel.enable` | `bool` | Route via Cloudflare tunnel instead of direct |

**`mkRoutes` route entry shape:**

```nix
{ subdomain, url, entryPoints?, middlewares? }
```

---

### grafana-dashboards.nix

Provides functions and pre-configured dashboard references for Grafana
provisioning.

**Purpose:** Centralise all dashboard fetch parameters (gnetId, revision, hash)
so they are updated in one place and referenced by name elsewhere.

**Usage pattern:**

```nix
let
  grafanaDashboards = import ./lib/grafana-dashboards.nix { inherit lib pkgs; };
in
{
  sys.services.grafana = {
    enable = true;
    provision.dashboards = {
      inherit (grafanaDashboards.community) node-exporter-full;
      inherit (grafanaDashboards.custom) zfs-overview power-consumption;
      # Or pull everything at once:
      # inherit (grafanaDashboards.all) node-exporter-full zfs-overview;
    };
  };
}
```

**Function signatures:**

| Function | Parameters | Returns |
|----------|------------|---------|
| `fetchGrafanaDashboard` | `{ gnetId, revision, hash, name? }` | `pkgs.fetchurl` derivation from grafana.com/api/dashboards |

**Available community dashboards** (fetched from grafana.com at build time):

| Key | gnetId | Revision | Description |
|-----|--------|----------|-------------|
| `community.node-exporter-full` | 1860 | 45 | Comprehensive node metrics |
| `community.kubernetes-cluster` | 315 | 3 | Kubernetes cluster overview |

**Available custom dashboards** (local JSON files):

| Key | Source path | Description |
|-----|-------------|-------------|
| `custom.arr-services` | `dashboards/shared/arr-services.json` | Sonarr/Radarr/etc metrics |
| `custom.zfs-overview` | `dashboards/host/blizzard/zfs-overview.json` | ZFS pool and dataset metrics |
| `custom.power-consumption` | `dashboards/shared/power-consumption.json` | Real-time power usage |
| `custom.power-consumption-historical` | `dashboards/host/blizzard/power-consumption-historical.json` | Historical power data |
| `custom.ups-monitoring` | `dashboards/host/blizzard/ups-monitoring.json` | UPS status and metrics |
| `custom.electricity-prices` | `dashboards/shared/electricity-prices.json` | Energy pricing data |

`all = community // custom` — convenient union of both sets.

**Adding a community dashboard:**

```nix
community = {
  my-dashboard = fetchGrafanaDashboard {
    gnetId = 12345;
    revision = 1;
    hash = "sha256-...";  # Use lib.fakeHash first, then update
  };
};
```

**Adding a custom dashboard:**

```nix
custom = {
  my-dashboard = ../dashboards/shared/my-dashboard.json;
};
```

---

### grafana.nix

Panel-builder DSL for authoring Grafana dashboard JSON in Nix. Eliminates
hand-editing large JSON blobs by providing typed constructor functions for every
panel kind.

**Purpose:** Build fully valid Grafana dashboard JSON from Nix expressions so
dashboards can reference variables, share field configs, and be composed
programmatically.

**Usage pattern:**

```nix
let
  g = import ./lib/grafana.nix { inherit lib; };
in
g.mkDashboard {
  title = "My Service";
  uid = "my-service-uid";
  tags = [ "myservice" ];
  panels = [
    (g.mkRow { title = "Overview"; id = 1; gridPos = { x = 0; y = 0; w = 24; h = 1; }; })
    (g.mkTimeseries {
      title = "Request Rate";
      id = 2;
      description = "Requests per second";
      gridPos = { x = 0; y = 1; w = 12; h = 8; };
      targets = [
        (g.mkTarget {
          expr = "rate(http_requests_total[5m])";
          legendFormat = "{{method}} {{status}}";
          refId = "A";
        })
      ];
    })
  ];
}
```

**Pre-built field config helpers:**

| Name | Description |
|------|-------------|
| `prometheusDatasource` | `{ type = "prometheus"; uid = "\${ds_prometheus}"; }` — standard Prometheus datasource reference |
| `defaultGaugeFieldConfig` | Gauge defaults: color-mode thresholds, 0–100% range, green/orange/red three-step |
| `defaultTimeseriesFieldConfig` | Timeseries defaults: palette-classic, line draw, fill opacity 40 |

**Panel constructor functions:**

| Function | Key Parameters | Description |
|----------|----------------|-------------|
| `mkRow` | `{ title, id, gridPos?, collapsed? }` | Section header / collapsible row |
| `mkGauge` | `{ title, id, description, gridPos, targets, fieldConfig?, thresholds?, unit? }` | Gauge panel |
| `mkStat` | `{ title, id, description?, gridPos, targets, unit?, decimals?, fieldConfig? }` | Single-value stat panel |
| `mkTimeseries` | `{ title, id, description, gridPos, targets, fieldConfig?, options?, unit? }` | Time-series graph panel |
| `mkBargauge` | `{ title, id, description, gridPos, targets, fieldConfig? }` | Horizontal bar gauge panel |

**Query and dashboard assembly functions:**

| Function | Key Parameters | Description |
|----------|----------------|-------------|
| `mkTarget` | `{ expr, legendFormat?, refId, instant?, exemplar? }` | Prometheus query target |
| `mkDashboard` | `{ title, uid?, panels, variables?, links?, tags?, annotations? }` | Assembles full Grafana dashboard JSON |

---

### Adding Things

| Task | Action |
|------|--------|
| New shared constant | Add to `constants.nix` and reference via `consts` in `specialArgs` |
| New Traefik middleware | Extend `mkSecurityHeaders` or add a helper in `traefik.nix` |
| New community dashboard | Add `fetchGrafanaDashboard` entry to `grafana-dashboards.nix` |
| New custom dashboard | Export JSON to `dashboards/`, add path to `custom` in `grafana-dashboards.nix` |
| New panel type | Add constructor function to `grafana.nix` following the existing pattern |

### Related

- [Grafana service module](../modules/services/grafana.nix)
- [Dashboard files](../dashboards/)
- [Traefik service module](../vms/traefik.nix)

