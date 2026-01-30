## Library Functions

Reusable Nix functions and data for the configuration.

### Modules

#### grafana-dashboards.nix

Provides functions and pre-configured dashboards for Grafana provisioning.

**Functions:**

| Function | Description |
|----------|-------------|
| `fetchGrafanaDashboard` | Fetch dashboard JSON from grafana.com |

**Dashboard Collections:**

| Collection | Description |
|------------|-------------|
| `community` | Popular dashboards from grafana.com |
| `custom` | Local dashboards from [dashboards/](../dashboards/) |
| `all` | Combined community + custom dashboards |

**Usage:**

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
    };
  };
}
```

**Available Community Dashboards:**

- `node-exporter-full` — Comprehensive node metrics (ID: 1860)
- `kubernetes-cluster` — Kubernetes overview (ID: 315)

**Available Custom Dashboards:**

- `zfs-overview` — ZFS pool and dataset metrics
- `power-consumption` — Power usage monitoring
- `power-consumption-historical` — Historical power data
- `ups-monitoring` — UPS status and metrics
- `electricity-prices` — Energy pricing data

#### grafana.nix

Helper functions for Grafana configuration.

### Adding Dashboards

#### From Grafana.com

1. Find the dashboard ID and revision on grafana.com
1. Add to `community` in [grafana-dashboards.nix](grafana-dashboards.nix):

```nix
community = {
  my-dashboard = fetchGrafanaDashboard {
    gnetId = 12345;
    revision = 1;
    hash = "sha256-...";  # Use lib.fakeHash first, then update
  };
};
```

#### Custom Dashboards

1. Export JSON from Grafana or create manually
1. Save to [dashboards/](../dashboards/) (shared or host-specific)
1. Reference in `custom`:

```nix
custom = {
  my-dashboard = ../dashboards/shared/my-dashboard.json;
};
```

### Related

- [Grafana service module](../modules/services/grafana.nix)
- [Dashboard files](../dashboards/)

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
