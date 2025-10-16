# Grafana Dashboard Automation - Summary

## What Was Created

A complete suite of Python scripts to automate the generation of Nix configuration files from Grafana dashboard JSON exports.

## File Structure

```
hosts/snowfall/dashboards/
├── ANALYSIS.md                          # Detailed analysis of dashboard structure
├── node-exporter-full.json              # Source Grafana dashboard JSON
├── node-exporter-full/                  # Generated Nix files directory
│   ├── default.nix                      # Main dashboard definition
│   ├── quick-overview.nix               # Quick CPU/Mem/Disk panels
│   ├── basic-panels.nix                 # Basic CPU/Mem/Net/Disk panels
│   ├── combined-detailed-panels.nix     # Combined detailed panels
│   ├── cpu-panels.nix                   # CPU-specific panels
│   ├── memory-panels.nix                # Memory panels
│   ├── memory-meminfo-panels.nix        # Memory meminfo panels
│   ├── memory-vmstat-panels.nix         # Memory vmstat panels
│   ├── system-timesync-panels.nix       # Time synchronization panels
│   ├── system-processes-panels.nix      # Process monitoring panels
│   ├── system-misc-panels.nix           # Miscellaneous system panels
│   ├── hardware-misc-panels.nix         # Hardware monitoring panels
│   ├── systemd-panels.nix               # Systemd panels
│   ├── storage-disk-panels.nix          # Disk storage panels
│   ├── storage-filesystem-panels.nix    # Filesystem panels
│   ├── network-traffic-panels.nix       # Network traffic panels
│   ├── network-sockstat-panels.nix      # Socket statistics panels
│   ├── network-netstat-panels.nix       # Network statistics panels
│   └── node-exporter-panels.nix         # Node exporter metrics panels
└── scripts/                             # Python automation scripts
    ├── README.md                        # Scripts documentation
    ├── 01_extract_panels.py             # JSON parsing and extraction
    ├── 02_generate_nix.py               # Nix code generation
    ├── 03_generate_all.py               # Main orchestration script
    ├── 04_validate.py                   # Validation and comparison
    ├── 05_quick_fixes.py                # Batch updates utility
    └── run_tools.py                     # Interactive menu interface
```

## Scripts Overview

### 1. Extract Panels (`01_extract_panels.py`)
- **Purpose**: Parse the JSON dashboard and organize panels by sections
- **Features**:
  - Extracts 16 dashboard sections
  - Identifies 5 panel types (row, gauge, stat, bargauge, timeseries)
  - Exports sections to separate JSON files for inspection
  - Provides metadata about sections and panel counts

### 2. Generate Nix Code (`02_generate_nix.py`)
- **Purpose**: Convert JSON panel definitions to Nix code
- **Features**:
  - Generates proper Nix syntax using `grafana.mk*` helpers
  - Handles all panel types with appropriate parameters
  - Formats multi-line strings and nested structures
  - Manages field config overrides and custom settings
  - Produces properly indented, readable code

### 3. Generate All Files (`03_generate_all.py`)
- **Purpose**: Complete automation of Nix file generation
- **Features**:
  - Processes all 16 dashboard sections
  - Generates individual `.nix` files for each section
  - Backs up existing files before overwriting
  - Maps section titles to filenames
  - Provides detailed progress reporting
  - Error tracking and summary statistics

### 4. Validate Dashboard (`04_validate.py`)
- **Purpose**: Validate generated Nix files against JSON source
- **Features**:
  - Checks file existence (17 expected files)
  - Compares panel counts between JSON and Nix
  - Validates panel IDs are unique
  - Compares panel titles between formats
  - Generates comprehensive validation report

### 5. Quick Fixes (`05_quick_fixes.py`)
- **Purpose**: Batch maintenance and updates
- **Features**:
  - Search patterns across all files
  - Batch find-and-replace operations
  - Indentation consistency checks
  - File and panel statistics
  - Safe updates with backup options

### 6. Master Interface (`run_tools.py`)
- **Purpose**: Interactive menu for all tools
- **Features**:
  - User-friendly menu system
  - Access to all scripts from one interface
  - Built-in help and confirmations
  - Error handling and reporting

## Key Findings from Analysis

### Dashboard Structure
- **16 sections** (rows) organizing 100+ panels
- **5 panel types**: row, gauge, stat, bargauge, timeseries
- **4 template variables**: datasource, job, nodename, instance
- **Collapsed sections**: Rows 3-16 are collapsed by default

### Configuration Details
- Dashboard UID: `rYdddlPWk`
- Time range: Last 24 hours
- Refresh: 1 minute
- Schema version: 41
- Grid system: 24 columns

### Identified Issues (Minor)
1. **Timezone mismatch**: JSON uses "browser", Nix uses ""
2. **Refresh mismatch**: JSON uses "1m", Nix helper uses "30s"
3. **Schema version**: JSON is v41, Nix helper is v39

### Status
✅ **All expected files exist and are properly structured**
✅ **All sections have corresponding Nix files**
✅ **Panel mappings are complete**
⚠️ **Minor configuration mismatches need fixing in `lib/grafana.nix`**

## How to Use

### Quick Start
```powershell
# Navigate to scripts directory
cd c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\scripts

# Run interactive menu
python run_tools.py
```

### Regenerate All Files
```powershell
# Backup existing files and regenerate from JSON
python 03_generate_all.py
```

### Validate Current Files
```powershell
# Check if Nix files match JSON dashboard
python 04_validate.py
```

### View Statistics
```powershell
# Show dashboard and file statistics
python run_tools.py
# Select option 6
```

## Benefits

1. **Automation**: Convert JSON dashboards to Nix automatically
2. **Consistency**: Uses standardized helpers from `lib/grafana.nix`
3. **Maintainability**: Easy to regenerate when dashboard updates
4. **Validation**: Tools to verify correctness
5. **Documentation**: Comprehensive analysis and guides
6. **Reusability**: Scripts can be adapted for other dashboards

## Technical Highlights

### Code Generation
- Proper Nix syntax with correct string escaping
- Multi-line string handling for complex expressions
- Nested structure formatting (dicts, lists)
- Field config overrides with proper indentation
- Threshold and color configurations

### Panel Type Support
- **Row**: Section headers with collapse state
- **Gauge**: Single value gauges with thresholds
- **Stat**: Single value statistics
- **Bargauge**: Multi-bar gauges (e.g., pressure)
- **Timeseries**: Time-based graphs with multiple series

### Query Handling
- Prometheus query expressions
- Variable substitution (`$node`, `$job`, etc.)
- Legend formatting
- Rate intervals and aggregations
- Multi-target panels

## Recommendations

### Immediate Actions
1. Fix `lib/grafana.nix` configuration mismatches
2. Run validation to verify current state
3. Review backup files before cleanup

### Future Maintenance
1. Update JSON when dashboard changes
2. Run `03_generate_all.py` to regenerate
3. Review and test changes
4. Commit updates to version control

### Extensions
Consider adapting scripts for:
- Other Grafana dashboards (Traefik, Prometheus, etc.)
- Different visualization types
- Custom panel configurations
- Dashboard templates

## Testing Notes

⚠️ **Important**: Scripts were created on Windows (non-Nix system)
- No Nix commands were executed
- No actual Nix tests were run
- Manual review recommended before deployment
- Test in a Nix environment before production use

## References

- Source JSON: `node-exporter-full.json`
- Analysis: `ANALYSIS.md`
- Helper library: `../../../../lib/grafana.nix`
- Dashboard ID: [Grafana 1860](https://grafana.com/grafana/dashboards/1860)

## Success Metrics

✅ All 16 sections identified and mapped
✅ All 19 Nix files accounted for
✅ 6 Python scripts created and documented
✅ Comprehensive analysis completed
✅ Validation tools provided
✅ Interactive interface created
✅ Full documentation written

## Next Steps

1. Review generated scripts
2. Fix configuration mismatches in `lib/grafana.nix`
3. Test scripts in development environment
4. Validate generated Nix files
5. Deploy to Nix system for testing
6. Document any system-specific adjustments

---

**Created**: October 16, 2025
**Status**: Complete - Ready for review and testing
**Environment**: Windows PowerShell (Non-Nix)
