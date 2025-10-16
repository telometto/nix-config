# Node Exporter Dashboard Analysis

## Dashboard Structure

The `node-exporter-full.json` dashboard contains **16 row sections** with their corresponding panels.

### Row Sections Mapping

| # | Row Title in JSON | Expected Nix File | Status |
|---|-------------------|-------------------|--------|
| 1 | Quick CPU / Mem / Disk | `quick-overview.nix` | ✅ EXISTS |
| 2 | Basic CPU / Mem / Net / Disk | `basic-panels.nix` | ✅ EXISTS |
| 3 | CPU / Memory / Net / Disk | `combined-detailed-panels.nix` | ✅ EXISTS |
| 4 | Memory Meminfo | `memory-meminfo-panels.nix` | ✅ EXISTS |
| 5 | Memory Vmstat | `memory-vmstat-panels.nix` | ✅ EXISTS |
| 6 | System Timesync | `system-timesync-panels.nix` | ✅ EXISTS |
| 7 | System Processes | `system-processes-panels.nix` | ✅ EXISTS |
| 8 | System Misc | `system-misc-panels.nix` | ✅ EXISTS |
| 9 | Hardware Misc | `hardware-misc-panels.nix` | ✅ EXISTS |
| 10 | Systemd | `systemd-panels.nix` | ✅ EXISTS |
| 11 | Storage Disk | `storage-disk-panels.nix` | ✅ EXISTS |
| 12 | Storage Filesystem | `storage-filesystem-panels.nix` | ✅ EXISTS |
| 13 | Network Traffic | `network-traffic-panels.nix` | ✅ EXISTS |
| 14 | Network Sockstat | `network-sockstat-panels.nix` | ✅ EXISTS |
| 15 | Network Netstat | `network-netstat-panels.nix` | ✅ EXISTS |
| 16 | Node Exporter | `node-exporter-panels.nix` | ✅ EXISTS |

### Missing Files

**NONE** - All expected Nix files exist and are properly imported in `default.nix`.

## Panel Types in Dashboard

The dashboard uses the following Grafana panel types:
1. **bargauge** - Bar gauge panels (e.g., Pressure panel)
2. **gauge** - Single gauge panels (e.g., CPU Busy, RAM Used)
3. **stat** - Stat panels showing single values (e.g., CPU Cores, RAM Total)
4. **timeseries** - Time series graphs (most common type)
5. **row** - Section headers (collapsible rows)

## Grafana Library Helpers

The `lib/grafana.nix` provides these helper functions:
- `mkRow` - Creates row section headers
- `mkGauge` - Creates gauge panels
- `mkStat` - Creates stat panels
- `mkTimeseries` - Creates time series panels
- `mkBargauge` - Creates bar gauge panels
- `mkTarget` - Creates Prometheus query targets
- `mkDashboard` - Assembles complete dashboard

## JSON Structure Overview

Each panel in the JSON contains:
- `id` - Unique panel identifier
- `title` - Panel display title
- `description` - Panel description (optional)
- `type` - Panel type (row, gauge, stat, timeseries, bargauge)
- `gridPos` - Grid position and size (x, y, w, h)
- `datasource` - Data source configuration (Prometheus)
- `targets` - Array of Prometheus queries
- `fieldConfig` - Field configuration including units, thresholds, overrides
- `options` - Panel-specific display options

## Configuration Observations

### Row Section IDs
- Row 1: id=261 (Quick CPU / Mem / Disk) - y=0
- Row 2: id=263 (Basic CPU / Mem / Net / Disk) - y=5
- Row 3: id=265 (CPU / Memory / Net / Disk) - y=20, **collapsed=true**
- Row 4: id=266 (Memory Meminfo) - y=21, **collapsed=true**
- Row 5: id=267 (Memory Vmstat) - y=22, **collapsed=true**
- Row 6: id=293 (System Timesync) - y=23, **collapsed=true**
- Row 7: id=312 (System Processes) - y=24, **collapsed=true**
- Row 8: id=269 (System Misc) - y=25, **collapsed=true**
- Row 9: id=304 (Hardware Misc) - y=26, **collapsed=true**
- Row 10: id=296 (Systemd) - y=27, **collapsed=true**
- Row 11: id=270 (Storage Disk) - y=28, **collapsed=true**
- Row 12: id=271 (Storage Filesystem) - y=29, **collapsed=true**
- Row 13: id=272 (Network Traffic) - y=30, **collapsed=true**
- Row 14: id=273 (Network Sockstat) - y=31, **collapsed=true**
- Row 15: id=274 (Network Netstat) - y=32, **collapsed=true**
- Row 16: id=279 (Node Exporter) - y=33, **collapsed=true**

**Note**: Rows 3-16 are collapsed by default, only the first two sections (Quick Overview and Basic panels) are expanded.

### Dashboard Variables (Templating)

The dashboard uses 4 template variables:
1. `ds_prometheus` - Datasource selector (type: datasource)
2. `job` - Job selector from label_values(node_uname_info, job)
3. `nodename` - Node name selector filtered by job
4. `node` - Instance selector (filtered by job and nodename)

These variables are used in all panel queries as `$node`, `$job`, etc.

### Common Query Patterns

Most queries follow these patterns:
- CPU metrics: `node_cpu_seconds_total{instance="$node",job="$job"}`
- Memory metrics: `node_memory_*_bytes{instance="$node",job="$job"}`
- Disk metrics: `node_disk_*{instance="$node",job="$job"}`
- Network metrics: `node_network_*{instance="$node",job="$job"}`
- Filesystem metrics: `node_filesystem_*{instance="$node",job="$job"}`

### Timezone and Refresh Settings

- Dashboard timezone: `"browser"` (uses browser's timezone)
- Refresh interval: `"1m"` (auto-refresh every minute)
- Default time range: last 24 hours (`"from": "now-24h", "to": "now"`)

## Potential Issues & Improvements

### 1. Timezone Configuration Mismatch
- **JSON**: `"timezone": "browser"`
- **Nix (lib/grafana.nix)**: `timezone = "";` (empty string)
- **Recommendation**: Update lib/grafana.nix to support browser timezone or make it configurable

### 2. Refresh Interval Mismatch
- **JSON**: `"refresh": "1m"`
- **Nix (lib/grafana.nix)**: `refresh = "30s";`
- **Recommendation**: Either update the Nix default or make it configurable per dashboard

### 3. Schema Version
- **JSON**: `"schemaVersion": 41`
- **Nix**: `schemaVersion = 39;`
- **Recommendation**: Update to match the latest schema version (41)

### 4. Missing UID in mkDashboard
The JSON has `"uid": "rYdddlPWk"` which is properly set in default.nix, but worth noting for other dashboards.

### 5. Annotations Configuration
- **JSON**: Uses `"uid": "grafana"` for annotations datasource
- **Nix**: Correctly replicates this
- **Status**: ✅ No issues

### 6. Panel Positioning
The panels use a 24-column grid system with varying heights. The y-positions increment based on previous panel heights. This is correctly handled by specifying gridPos for each panel.

### 7. Step Parameter in Targets
Most queries in JSON use `"step": 240`, but the Nix mkTarget helper hardcodes `step = 240;`. This is consistent.

### 8. Collapsed Rows Configuration
The Nix helper `mkRow` has `collapsed ? false` default, but most rows in the JSON (rows 3-16) should be collapsed. Need to ensure this is properly set when generating the Nix files.

## Summary

✅ **Structure is complete** - All 16 row sections have corresponding Nix files
✅ **All files are imported** - default.nix correctly imports all panel modules
✅ **Panel types supported** - All required panel types have helper functions in lib/grafana.nix

⚠️ **Minor configuration mismatches** to fix:
1. Timezone setting (browser vs empty string)
2. Refresh interval (1m vs 30s) 
3. Schema version (41 vs 39)
4. Ensure collapsed state is properly set for rows 3-16

## Next Steps

✅ **COMPLETED**: Python scripts have been created to:
1. Parse the JSON dashboard chunk by chunk (by row sections) ✅
2. Extract panel definitions from each section ✅
3. Convert JSON panel configurations to Nix function calls ✅
4. Generate properly formatted Nix files with correct indentation ✅
5. Handle panel-specific overrides and custom configurations ✅
6. Validate generated Nix matches the JSON structure ✅

### Available Scripts

All scripts are located in the `scripts/` directory:

- **`01_extract_panels.py`** - Parse JSON and extract panel definitions by section
- **`02_generate_nix.py`** - Convert JSON panels to Nix code
- **`03_generate_all.py`** - Main orchestration script to regenerate all Nix files
- **`04_validate.py`** - Validate Nix files against JSON dashboard
- **`05_quick_fixes.py`** - Batch updates and pattern replacements
- **`run_tools.py`** - Master script with menu interface

### Usage

Run the master script for an interactive menu:
```powershell
cd scripts
python run_tools.py
```

Or run individual scripts:
```powershell
python 03_generate_all.py  # Regenerate all Nix files
python 04_validate.py      # Validate existing files
```

### Recommended Actions

1. **Fix configuration mismatches** in `lib/grafana.nix`:
   - Update `timezone = "";` to `timezone = "browser";`
   - Update `refresh = "30s";` to `refresh = "1m";`
   - Update `schemaVersion = 39;` to `schemaVersion = 41;`

2. **Run validation** to ensure all files are correctly structured:
   ```powershell
   python scripts/04_validate.py
   ```

3. **Consider regenerating files** if major changes were made to the JSON:
   ```powershell
   python scripts/03_generate_all.py
   ```

### Future Maintenance

When the dashboard JSON is updated:
1. Replace `node-exporter-full.json` with the new version
2. Run `python scripts/03_generate_all.py` to regenerate Nix files
3. Review changes and test the configuration
4. Commit the updates

The scripts are designed to be reusable and can be adapted for other Grafana dashboards with minimal modifications.
