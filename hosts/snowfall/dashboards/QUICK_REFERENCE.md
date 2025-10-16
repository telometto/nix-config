# Quick Reference Guide

## Analysis Results

### ✅ Dashboard Structure
- **16 sections** fully mapped to Nix files
- **ALL files exist** - No missing configurations
- **100+ panels** across all sections
- **No structural issues found**

### ⚠️ Minor Configuration Mismatches

Three minor discrepancies in `lib/grafana.nix` (not critical):

1. **Timezone**: JSON uses `"browser"`, Nix uses `""`
2. **Refresh**: JSON uses `"1m"`, Nix uses `"30s"`
3. **Schema Version**: JSON uses `41`, Nix uses `39`

## Generated Scripts

### Quick Access Commands

```powershell
# Navigate to scripts directory
cd c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\scripts

# Interactive menu (recommended)
python run_tools.py

# Individual tools
python 01_extract_panels.py    # Parse and analyze JSON
python 02_generate_nix.py       # Demo Nix code generation
python 03_generate_all.py       # Regenerate ALL Nix files (with backup)
python 04_validate.py           # Validate existing files
python 05_quick_fixes.py        # Batch updates and stats
```

## What Each Script Does

| Script | Purpose | Safe to Run? |
|--------|---------|--------------|
| `01_extract_panels.py` | Analyze JSON structure | ✅ Yes (read-only) |
| `02_generate_nix.py` | Demo code generation | ✅ Yes (demo only) |
| `03_generate_all.py` | **Regenerate all files** | ⚠️ Creates backups first |
| `04_validate.py` | Compare JSON vs Nix | ✅ Yes (read-only) |
| `05_quick_fixes.py` | Search and stats | ✅ Yes (read-only mode) |
| `run_tools.py` | Interactive menu | ✅ Yes (prompts for actions) |

## Typical Workflows

### Workflow 1: Check Current State
```powershell
cd scripts
python 04_validate.py
```
**Output**: Validation report showing files, panel counts, and any issues

### Workflow 2: View Statistics
```powershell
cd scripts
python run_tools.py
# Select option 6: View Statistics
```
**Output**: Dashboard and file statistics

### Workflow 3: Regenerate Everything (After JSON Update)
```powershell
cd scripts
python 03_generate_all.py
# Confirms before proceeding
# Creates .backup files automatically
```
**Output**: All 16 panel Nix files regenerated

### Workflow 4: Search for Patterns
```powershell
cd scripts
python 05_quick_fixes.py
# Shows statistics and pattern search examples
```

## Section to File Mapping

| # | Dashboard Section | Nix File |
|---|-------------------|----------|
| 1 | Quick CPU / Mem / Disk | `quick-overview.nix` |
| 2 | Basic CPU / Mem / Net / Disk | `basic-panels.nix` |
| 3 | CPU / Memory / Net / Disk | `combined-detailed-panels.nix` |
| 4 | Memory Meminfo | `memory-meminfo-panels.nix` |
| 5 | Memory Vmstat | `memory-vmstat-panels.nix` |
| 6 | System Timesync | `system-timesync-panels.nix` |
| 7 | System Processes | `system-processes-panels.nix` |
| 8 | System Misc | `system-misc-panels.nix` |
| 9 | Hardware Misc | `hardware-misc-panels.nix` |
| 10 | Systemd | `systemd-panels.nix` |
| 11 | Storage Disk | `storage-disk-panels.nix` |
| 12 | Storage Filesystem | `storage-filesystem-panels.nix` |
| 13 | Network Traffic | `network-traffic-panels.nix` |
| 14 | Network Sockstat | `network-sockstat-panels.nix` |
| 15 | Network Netstat | `network-netstat-panels.nix` |
| 16 | Node Exporter | `node-exporter-panels.nix` |

## Panel Types Supported

- ✅ **row** - Section headers with collapse state
- ✅ **gauge** - Single gauge panels (CPU Busy, RAM Used, etc.)
- ✅ **stat** - Single value displays (CPU Cores, RAM Total, etc.)
- ✅ **bargauge** - Multi-bar gauges (Pressure panel)
- ✅ **timeseries** - Time series graphs (most common)

## Safety Features

### Automatic Backups
When running `03_generate_all.py`:
- Existing `.nix` files → `.nix.backup`
- Multiple runs → `.nix.backup1`, `.nix.backup2`, etc.
- Original files preserved

### Dry Run Mode
Most scripts support read-only operation:
```python
# Example in 05_quick_fixes.py
updater.replace_in_all_files("old", "new", dry_run=True)
```

### Validation Before Deploy
Always run validation before using generated files:
```powershell
python 04_validate.py
```

## Common Questions

### Q: Will this work on my Nix system?
**A**: Scripts were created on Windows, but generate standard Nix syntax. Test in dev environment first.

### Q: Can I customize the generated code?
**A**: Yes! Edit generated files manually or modify the generation scripts.

### Q: What if I only want to regenerate one file?
**A**: Edit `03_generate_all.py` or extract/generate manually using `01_extract_panels.py` + `02_generate_nix.py`.

### Q: How do I update when the dashboard changes?
**A**: 
1. Update `node-exporter-full.json`
2. Run `python 03_generate_all.py`
3. Review changes
4. Test in Nix environment

### Q: Are there dependencies?
**A**: No! All scripts use Python standard library only.

## File Locations

```
Repository Root
└── hosts/snowfall/dashboards/
    ├── ANALYSIS.md              ← Detailed analysis
    ├── SUMMARY.md               ← Complete summary
    ├── QUICK_REFERENCE.md       ← This file
    ├── node-exporter-full.json  ← Source dashboard
    ├── node-exporter-full/      ← Generated Nix files
    └── scripts/                 ← Python automation
        ├── README.md            ← Scripts documentation
        ├── 01_extract_panels.py
        ├── 02_generate_nix.py
        ├── 03_generate_all.py
        ├── 04_validate.py
        ├── 05_quick_fixes.py
        └── run_tools.py         ← Start here!
```

## Key Metrics

- ✅ 16/16 sections mapped
- ✅ 19/19 files accounted for
- ✅ 6 automation scripts created
- ✅ 0 missing configurations
- ⚠️ 3 minor config mismatches (non-critical)

## Recommendations

### Priority 1 (Optional)
Fix minor configuration mismatches in `lib/grafana.nix`:
- Line ~458: Change `timezone = "";` to `timezone = "browser";`
- Line ~459: Change `refresh = "30s";` to `refresh = "1m";`
- Line ~460: Change `schemaVersion = 39;` to `schemaVersion = 41;`

### Priority 2 (Before Deployment)
Run validation to ensure everything is correct:
```powershell
python scripts/04_validate.py
```

### Priority 3 (After Any Changes)
Test in a Nix development environment before production.

## Support Files

- **ANALYSIS.md** - Detailed technical analysis
- **SUMMARY.md** - Complete project summary
- **scripts/README.md** - Script usage guide
- **This file** - Quick reference

---

**Status**: ✅ Complete
**Last Updated**: October 16, 2025
**Environment**: Windows PowerShell
