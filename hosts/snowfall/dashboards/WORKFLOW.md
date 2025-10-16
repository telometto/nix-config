# Dashboard Generation Workflow

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Grafana Dashboard System                         │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│  node-exporter-      │
│  full.json           │  ◄── Source: Grafana Dashboard Export (JSON)
│  (16 sections)       │      • 16 row sections
│  (100+ panels)       │      • 5 panel types
└──────────┬───────────┘      • Template variables
           │
           │ parsed by
           ▼
┌──────────────────────┐
│  01_extract_panels   │  ◄── Parser & Extractor
│  .py                 │      • Loads JSON
└──────────┬───────────┘      • Organizes by section
           │                  • Extracts metadata
           │
           │ provides data to
           ▼
┌──────────────────────┐
│  02_generate_nix     │  ◄── Code Generator
│  .py                 │      • Converts JSON → Nix
└──────────┬───────────┘      • Uses grafana.mk* helpers
           │                  • Formats code properly
           │
           │ used by
           ▼
┌──────────────────────┐
│  03_generate_all     │  ◄── Main Orchestrator
│  .py                 │      • Processes all sections
└──────────┬───────────┘      • Creates backups
           │                  • Writes Nix files
           │
           │ generates
           ▼
┌──────────────────────────────────────────────────────────────────┐
│  node-exporter-full/  (19 Nix files)                             │
├──────────────────────────────────────────────────────────────────┤
│  • default.nix                    ◄── Main dashboard definition  │
│  • quick-overview.nix             ◄── Section 1 panels           │
│  • basic-panels.nix               ◄── Section 2 panels           │
│  • combined-detailed-panels.nix   ◄── Section 3 panels           │
│  • cpu-panels.nix                 ◄── CPU metrics                │
│  • memory-panels.nix              ◄── Memory metrics             │
│  • memory-meminfo-panels.nix      ◄── Memory details             │
│  • memory-vmstat-panels.nix       ◄── Virtual memory             │
│  • system-timesync-panels.nix     ◄── Time sync                  │
│  • system-processes-panels.nix    ◄── Process monitoring         │
│  • system-misc-panels.nix         ◄── System misc                │
│  • hardware-misc-panels.nix       ◄── Hardware misc              │
│  • systemd-panels.nix             ◄── Systemd units              │
│  • storage-disk-panels.nix        ◄── Disk metrics               │
│  • storage-filesystem-panels.nix  ◄── Filesystem metrics         │
│  • network-traffic-panels.nix     ◄── Network traffic            │
│  • network-sockstat-panels.nix    ◄── Socket stats               │
│  • network-netstat-panels.nix     ◄── Network stats              │
│  • node-exporter-panels.nix       ◄── Node exporter metrics      │
└──────────┬───────────────────────────────────────────────────────┘
           │
           │ validated by
           ▼
┌──────────────────────┐
│  04_validate.py      │  ◄── Validator & Comparator
└──────────────────────┘      • Compares JSON ↔ Nix
           │                  • Checks panel counts
           │                  • Validates structure
           │
           │ maintained by
           ▼
┌──────────────────────┐
│  05_quick_fixes.py   │  ◄── Maintenance Tools
└──────────────────────┘      • Pattern search
                              • Batch updates
                              • Statistics

┌──────────────────────┐
│  run_tools.py        │  ◄── Interactive Menu (Master Script)
└──────────────────────┘      • User-friendly interface
                              • Access to all tools
                              • Error handling
```

## Data Flow

```
JSON Dashboard
     │
     │ Parse & Extract
     ▼
Section Data
     │
     │ Generate Code
     ▼
Nix Syntax
     │
     │ Format & Write
     ▼
.nix Files
     │
     │ Validate
     ▼
Production Ready
```

## Component Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    lib/grafana.nix                           │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Helper Functions                                   │     │
│  │  • mkRow()       - Create section headers          │     │
│  │  • mkGauge()     - Create gauge panels             │     │
│  │  • mkStat()      - Create stat panels              │     │
│  │  • mkBargauge()  - Create bar gauge panels         │     │
│  │  • mkTimeseries()- Create time series panels       │     │
│  │  • mkTarget()    - Create Prometheus queries       │     │
│  │  • mkDashboard() - Assemble complete dashboard     │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ imported and used by
                  ▼
┌─────────────────────────────────────────────────────────────┐
│           Generated Nix Files (19 files)                     │
│                                                              │
│  Each file:                                                  │
│  1. Imports lib/grafana.nix                                  │
│  2. Calls grafana.mk* functions                              │
│  3. Returns { panels = [...]; }                              │
│                                                              │
│  Example structure:                                          │
│  ┌────────────────────────────────────────┐                 │
│  │ { lib, grafana }:                      │                 │
│  │                                        │                 │
│  │ {                                      │                 │
│  │   panels = [                           │                 │
│  │     (grafana.mkRow { ... })            │                 │
│  │     (grafana.mkGauge { ... })          │                 │
│  │     (grafana.mkTimeseries { ... })     │                 │
│  │   ];                                   │                 │
│  │ }                                      │                 │
│  └────────────────────────────────────────┘                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ imported by
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    default.nix                               │
│  ┌────────────────────────────────────────────────────┐     │
│  │  1. Imports all section files                      │     │
│  │  2. Combines panels: lib.flatten [...]             │     │
│  │  3. Adds variables & links                         │     │
│  │  4. Calls grafana.mkDashboard                      │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ produces
                  ▼
┌─────────────────────────────────────────────────────────────┐
│            Complete Grafana Dashboard (JSON)                 │
│            Ready for deployment to Grafana                   │
└─────────────────────────────────────────────────────────────┘
```

## Script Dependencies

```
run_tools.py (Master Menu)
    │
    ├─► 01_extract_panels.py
    │        │
    │        └─► DashboardParser class
    │
    ├─► 02_generate_nix.py
    │        │
    │        └─► NixCodeGenerator class
    │
    ├─► 03_generate_all.py
    │        │
    │        ├─► imports: DashboardParser
    │        └─► imports: NixCodeGenerator
    │
    ├─► 04_validate.py
    │        │
    │        ├─► DashboardValidator class
    │        ├─► ComparisonTool class
    │        └─► imports: DashboardParser
    │
    └─► 05_quick_fixes.py
             │
             └─► NixFileUpdater class
```

## Process Flow: Regenerating Files

```
START
  │
  ├─► User runs: python 03_generate_all.py
  │
  ├─► Script loads node-exporter-full.json
  │
  ├─► DashboardParser extracts 16 sections
  │
  ├─► For each section:
  │    ├─► Map section title to filename
  │    ├─► Extract row + panels
  │    ├─► Generate Nix code via NixCodeGenerator
  │    ├─► Backup existing .nix file (if exists)
  │    └─► Write new .nix file
  │
  ├─► Print summary:
  │    ├─► Sections processed: 16
  │    ├─► Panels generated: 100+
  │    ├─► Files written: 16
  │    └─► Files backed up: 16
  │
END (Success/Failure report)
```

## Validation Flow

```
START
  │
  ├─► User runs: python 04_validate.py
  │
  ├─► Load JSON dashboard
  │
  ├─► Check all expected files exist
  │    └─► Report: ✅ 19/19 files found
  │
  ├─► Compare panel counts:
  │    └─► For each section:
  │         ├─► JSON panels: X
  │         ├─► Nix panels (estimated): Y
  │         └─► Status: ✅ or ⚠️
  │
  ├─► Check panel IDs unique
  │    └─► Report: ✅ All unique
  │
  ├─► Compare panel titles
  │    └─► Report differences
  │
  ├─► Print validation report
  │
END
```

## Panel Generation Example

```
JSON Panel:
┌─────────────────────────────────────────┐
│ {                                       │
│   "id": 20,                             │
│   "title": "CPU Busy",                  │
│   "type": "gauge",                      │
│   "targets": [{                         │
│     "expr": "100 * (1 - avg(...))",     │
│     "refId": "A"                        │
│   }]                                    │
│ }                                       │
└─────────────────────────────────────────┘
         │
         │ Processed by NixCodeGenerator
         ▼
Nix Code:
┌─────────────────────────────────────────┐
│ (grafana.mkGauge {                      │
│   title = "CPU Busy";                   │
│   id = 20;                              │
│   description = "...";                  │
│   gridPos = { h=4; w=3; x=3; y=1; };    │
│   targets = [                           │
│     (grafana.mkTarget {                 │
│       expr = ''100 * (1 - avg(...))'';  │
│       refId = "A";                      │
│     })                                  │
│   ];                                    │
│ })                                      │
└─────────────────────────────────────────┘
```

## File Structure Overview

```
nix-config/
├── lib/
│   └── grafana.nix                    ◄── Helper functions
│
└── hosts/snowfall/dashboards/
    ├── ANALYSIS.md                    ◄── Technical analysis
    ├── SUMMARY.md                     ◄── Project summary
    ├── QUICK_REFERENCE.md             ◄── Quick guide
    ├── WORKFLOW.md                    ◄── This file
    │
    ├── node-exporter-full.json        ◄── Source dashboard
    │
    ├── node-exporter-full/            ◄── Generated Nix files
    │   ├── default.nix                    (19 files total)
    │   ├── *-panels.nix (x16)
    │   └── ...
    │
    └── scripts/                       ◄── Automation tools
        ├── README.md                      (6 scripts)
        ├── 01_extract_panels.py
        ├── 02_generate_nix.py
        ├── 03_generate_all.py
        ├── 04_validate.py
        ├── 05_quick_fixes.py
        └── run_tools.py
```

---

**Legend:**
- `◄──` Points to description
- `│`, `├─►`, `└─►` Flow direction
- `✅` Success/Complete
- `⚠️` Warning/Check needed
