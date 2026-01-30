## Grafana Dashboards

JSON dashboard definitions for Grafana provisioning.

### Structure

```
dashboards/
├── shared/              # Dashboards usable across hosts
│   ├── electricity-prices.json
│   └── power-consumption.json
└── host/
    └── blizzard/        # Host-specific dashboards
        ├── zfs-overview.json
        ├── power-consumption-historical.json
        └── ups-monitoring.json
```

### Shared Dashboards

| Dashboard | Description | Data Source |
|-----------|-------------|-------------|
| [electricity-prices.json](shared/electricity-prices.json) | Energy pricing visualization | Electricity price exporter |
| [power-consumption.json](shared/power-consumption.json) | Real-time power usage | Smart plug metrics |

### Host-Specific Dashboards

#### Blizzard

| Dashboard | Description | Data Source |
|-----------|-------------|-------------|
| [zfs-overview.json](host/blizzard/zfs-overview.json) | ZFS pool health and usage | ZFS exporter |
| [power-consumption-historical.json](host/blizzard/power-consumption-historical.json) | Historical power analysis | Prometheus/VictoriaMetrics |
| [ups-monitoring.json](host/blizzard/ups-monitoring.json) | UPS status and battery | NUT exporter |

### Usage

Dashboards are referenced in host configurations via
[lib/grafana-dashboards.nix](../lib/grafana-dashboards.nix):

```nix
let
  grafanaDashboards = import ./lib/grafana-dashboards.nix { inherit lib pkgs; };
in
{
  sys.services.grafana.provision.dashboards = {
    inherit (grafanaDashboards.custom)
      zfs-overview
      power-consumption
      ups-monitoring;
  };
}
```

### Creating a New Dashboard

1. **Design in Grafana UI** — Build and test your dashboard interactively

2. **Export JSON** — Dashboard Settings → JSON Model → Copy

3. **Save to appropriate location:**
   - `dashboards/shared/` for multi-host dashboards
   - `dashboards/host/<hostname>/` for host-specific dashboards

4. **Register in library** — Add to `custom` in
   [lib/grafana-dashboards.nix](../lib/grafana-dashboards.nix):
   ```nix
   custom = {
     my-dashboard = ../dashboards/shared/my-dashboard.json;
   };
   ```

5. **Provision in host config** — Reference in
   `sys.services.grafana.provision.dashboards`

### Dashboard Guidelines

- Use variables for data source selection
- Include documentation panels explaining metrics
- Set appropriate refresh intervals
- Use consistent color schemes across dashboards
- Test with actual data before committing

### Related

- [Grafana service module](../modules/services/grafana.nix)
- [Grafana dashboards library](../lib/grafana-dashboards.nix)
- [Prometheus exporters](../modules/services/prometheus-exporters.nix)
