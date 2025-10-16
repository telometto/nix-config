# Grafana Dashboards for NixOS

This directory contains Grafana dashboard configurations written in Nix, along with complete automation tools for converting Grafana JSON exports to Nix code.

## 📚 Quick Navigation

**New here?** Start with → **[INDEX.md](INDEX.md)** for complete documentation index

### Essential Documents
- 🚀 **[INDEX.md](INDEX.md)** - Complete documentation index and navigation
- ⚡ **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick commands and common tasks
- 📖 **[SUMMARY.md](SUMMARY.md)** - Complete project summary
- 🔍 **[ANALYSIS.md](ANALYSIS.md)** - Technical analysis of dashboard structure
- 📊 **[WORKFLOW.md](WORKFLOW.md)** - Visual diagrams and architecture
- 🔧 **[scripts/README.md](scripts/README.md)** - Automation scripts guide

## 🎯 Quick Start

### Validate Current Dashboard
```powershell
cd scripts
python 04_validate.py
```

### Interactive Menu
```powershell
cd scripts
python run_tools.py
```

### View Statistics
```powershell
cd scripts
python run_tools.py
# Select option 6: View Statistics
```

## 📁 Directory Structure

```
dashboards/
├── README.md                       ← You are here
├── INDEX.md                        ← Complete documentation index
├── QUICK_REFERENCE.md              ← Quick commands guide
├── SUMMARY.md                      ← Project summary
├── ANALYSIS.md                     ← Technical analysis
├── WORKFLOW.md                     ← Diagrams & flows
│
├── node-exporter-full.json         ← Source: Grafana dashboard export
│
├── node-exporter-full/             ← Generated Nix configuration
│   ├── default.nix                 ← Main dashboard definition
│   ├── quick-overview.nix          ← Quick CPU/Mem/Disk section
│   ├── basic-panels.nix            ← Basic monitoring section
│   ├── combined-detailed-panels.nix
│   ├── cpu-panels.nix
│   ├── memory-panels.nix
│   ├── memory-meminfo-panels.nix
│   ├── memory-vmstat-panels.nix
│   ├── system-timesync-panels.nix
│   ├── system-processes-panels.nix
│   ├── system-misc-panels.nix
│   ├── hardware-misc-panels.nix
│   ├── systemd-panels.nix
│   ├── storage-disk-panels.nix
│   ├── storage-filesystem-panels.nix
│   ├── network-traffic-panels.nix
│   ├── network-sockstat-panels.nix
│   ├── network-netstat-panels.nix
│   └── node-exporter-panels.nix
│
└── scripts/                        ← Python automation tools
    ├── README.md                   ← Scripts documentation
    ├── 01_extract_panels.py        ← JSON parser & extractor
    ├── 02_generate_nix.py          ← Nix code generator
    ├── 03_generate_all.py          ← Main orchestration script
    ├── 04_validate.py              ← Validation & comparison
    ├── 05_quick_fixes.py           ← Maintenance utilities
    └── run_tools.py                ← Interactive menu interface
```

## 🔍 What's Here

### Node Exporter Full Dashboard
A comprehensive monitoring dashboard for Linux systems using Prometheus Node Exporter, featuring:
- **16 organized sections** (CPU, Memory, Network, Disk, System, etc.)
- **100+ monitoring panels** (gauges, stats, graphs, timeseries)
- **Prometheus integration** with configurable data sources
- **Collapsible sections** for detailed metrics on-demand

### Automation System
Complete Python toolchain for dashboard maintenance:
- ✅ **JSON → Nix conversion** (automatic code generation)
- ✅ **Validation tools** (verify correctness)
- ✅ **Interactive interface** (user-friendly menu)
- ✅ **Batch operations** (search, update, statistics)
- ✅ **Safe backups** (automatic file preservation)

### Comprehensive Documentation
Six detailed documentation files covering:
- Quick reference commands
- Complete project summary
- Technical analysis
- Visual workflows
- Usage guides

## ✨ Key Features

### For Users
- 🎯 **Easy to use** - Interactive menu interface
- 🔒 **Safe operations** - Automatic backups before changes
- 📊 **Statistics** - View dashboard and file metrics
- ✅ **Validation** - Verify configuration correctness

### For Developers
- 🔧 **Modular design** - Clean separation of concerns
- 📝 **Well documented** - Comprehensive guides
- 🎨 **Code generation** - Automatic Nix code creation
- 🔍 **Analysis tools** - Deep dashboard inspection

### For Maintainers
- 🔄 **Easy updates** - Regenerate from JSON in seconds
- 🔎 **Pattern search** - Find and replace across files
- 📈 **Monitoring** - Track file and panel statistics
- 🛡️ **Version control** - Safe backup mechanism

## 🚀 Common Workflows

### Check Dashboard Status
```powershell
cd scripts
python 04_validate.py
```
**Output**: Validation report with file status and panel counts

### Update Dashboard from JSON
```powershell
cd scripts
python 03_generate_all.py
```
**Output**: All panel files regenerated with automatic backups

### Search for Metrics
```powershell
cd scripts
python 05_quick_fixes.py
```
**Output**: Pattern search results and file statistics

## 📖 Documentation Guide

| Document | Best For | Read Time |
|----------|----------|-----------|
| [INDEX.md](INDEX.md) | Navigation & overview | 5 min |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Commands & quick tasks | 5 min |
| [SUMMARY.md](SUMMARY.md) | Complete details | 10 min |
| [ANALYSIS.md](ANALYSIS.md) | Technical deep-dive | 8 min |
| [WORKFLOW.md](WORKFLOW.md) | Visual understanding | 6 min |
| [scripts/README.md](scripts/README.md) | Script usage | 10 min |

## 🎓 Getting Started Paths

### Path 1: Quick User
1. Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
2. Run `python scripts/run_tools.py`
3. Explore the menu options

### Path 2: Technical Review
1. Read [ANALYSIS.md](ANALYSIS.md)
2. Review [WORKFLOW.md](WORKFLOW.md)
3. Check [SUMMARY.md](SUMMARY.md)

### Path 3: Maintenance
1. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
2. Review [scripts/README.md](scripts/README.md)
3. Run validation and statistics

## ⚡ Quick Commands

```powershell
# Navigate to scripts
cd scripts

# Interactive menu (recommended)
python run_tools.py

# Or run specific tools:
python 01_extract_panels.py    # Analyze JSON
python 03_generate_all.py       # Regenerate all (with backup)
python 04_validate.py           # Validate files
python 05_quick_fixes.py        # Stats & search
```

## 📊 Project Status

| Aspect | Status |
|--------|--------|
| Dashboard Analysis | ✅ Complete |
| Nix Files | ✅ All 19 files exist |
| Automation Scripts | ✅ All 6 scripts created |
| Documentation | ✅ 6 comprehensive docs |
| Validation Tools | ✅ Provided |
| Testing | ⏳ Ready for Nix testing |

## 🔗 Related Files

- **Helper Library**: `../../../../lib/grafana.nix` (Grafana helper functions)
- **Source Dashboard**: Based on [Grafana Dashboard 1860](https://grafana.com/grafana/dashboards/1860)

## 💡 Tips

- **Always backup**: Scripts create backups automatically, but manual backups never hurt
- **Validate often**: Run `04_validate.py` after any manual changes
- **Test in dev**: Always test generated Nix in a dev environment first
- **Read the docs**: Comprehensive documentation available for all aspects

## ⚠️ Important Notes

- Scripts created on Windows (PowerShell environment)
- No Nix commands executed during development
- Test generated Nix in proper Nix environment before production
- Minor configuration mismatches documented in [ANALYSIS.md](ANALYSIS.md)

## 🆘 Need Help?

1. **Quick commands** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
2. **Understanding project** → [INDEX.md](INDEX.md)
3. **Script usage** → [scripts/README.md](scripts/README.md)
4. **Technical details** → [ANALYSIS.md](ANALYSIS.md)
5. **Visual guides** → [WORKFLOW.md](WORKFLOW.md)

## 📅 Last Updated

**October 16, 2025** - Complete automation system created with full documentation

---

**For complete documentation index and navigation, see [INDEX.md](INDEX.md)**
