# Dashboard Generation Scripts

This directory contains Python scripts to automatically generate Nix configuration files from the Grafana `node-exporter-full.json` dashboard.

## Overview

The scripts work together to parse the JSON dashboard, extract panel definitions, and generate properly formatted Nix code that uses the helper functions from `lib/grafana.nix`.

## Scripts

### 01_extract_panels.py
**Purpose**: Parse the dashboard JSON and extract panel definitions organized by sections.

**Features**:
- Loads and parses `node-exporter-full.json`
- Organizes panels by their row sections
- Extracts metadata about sections and panels
- Can export individual sections to separate JSON files for inspection

**Usage**:
```powershell
python 01_extract_panels.py
```

**Output**:
- Prints section metadata and panel type summary
- Exports extracted sections to `extracted_sections/` directory (optional)

### 02_generate_nix.py
**Purpose**: Convert JSON panel definitions into Nix code.

**Features**:
- Generates Nix function calls using `grafana.mk*` helpers
- Handles all panel types: `row`, `gauge`, `stat`, `bargauge`, `timeseries`
- Properly formats strings, lists, dictionaries, and nested structures
- Handles field config overrides and custom settings
- Generates properly indented, readable Nix code

**Usage**:
```powershell
python 02_generate_nix.py
```

**Output**:
- Demo output showing generated code for a sample panel

### 03_generate_all.py
**Purpose**: Main orchestration script that generates all Nix files.

**Features**:
- Processes all 16 dashboard sections
- Generates individual `.nix` files for each section
- Backs up existing files before overwriting (`.backup` suffix)
- Provides detailed progress and error reporting
- Maps section titles to correct filenames

**Usage**:
```powershell
python 03_generate_all.py
```

**Output**:
- Generates/updates all panel Nix files in `node-exporter-full/`
- Creates backups of existing files
- Prints summary statistics

## File Mapping

The scripts use the following mapping from dashboard sections to Nix files:

| Dashboard Section | Nix File |
|-------------------|----------|
| Quick CPU / Mem / Disk | `quick-overview.nix` |
| Basic CPU / Mem / Net / Disk | `basic-panels.nix` |
| CPU / Memory / Net / Disk | `combined-detailed-panels.nix` |
| Memory Meminfo | `memory-meminfo-panels.nix` |
| Memory Vmstat | `memory-vmstat-panels.nix` |
| System Timesync | `system-timesync-panels.nix` |
| System Processes | `system-processes-panels.nix` |
| System Misc | `system-misc-panels.nix` |
| Hardware Misc | `hardware-misc-panels.nix` |
| Systemd | `systemd-panels.nix` |
| Storage Disk | `storage-disk-panels.nix` |
| Storage Filesystem | `storage-filesystem-panels.nix` |
| Network Traffic | `network-traffic-panels.nix` |
| Network Sockstat | `network-sockstat-panels.nix` |
| Network Netstat | `network-netstat-panels.nix` |
| Node Exporter | `node-exporter-panels.nix` |

## Requirements

- Python 3.7 or higher
- No external dependencies (uses only standard library)

## Workflow

### Complete Regeneration

To completely regenerate all Nix files from the JSON dashboard:

```powershell
cd c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\scripts

# Run the main generation script
python 03_generate_all.py
```

This will:
1. Parse the JSON dashboard
2. Extract all sections and panels
3. Generate Nix code for each section
4. Backup existing `.nix` files (with `.backup` suffix)
5. Write new `.nix` files
6. Print a summary report

### Inspecting Sections

To explore the dashboard structure and export sections for inspection:

```powershell
python 01_extract_panels.py
```

This will create an `extracted_sections/` directory with JSON files for each section.

### Testing Code Generation

To test the Nix code generation on a sample panel:

```powershell
python 02_generate_nix.py
```

## Configuration

The scripts can be configured by editing the paths in the `main()` function of each script:

### 03_generate_all.py
```python
json_path = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full.json"
output_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full"
```

### Backup Behavior

By default, existing files are backed up before being overwritten. To disable this:

```python
generator = DashboardNixGenerator(
    json_path=json_path,
    output_dir=output_dir,
    backup_existing=False  # Changed from True
)
```

## Generated Code Structure

Each generated Nix file has the following structure:

```nix
{ lib, grafana }:

{
  panels = [
    # Row header
    (grafana.mkRow {
      title = "Section Title";
      id = 123;
      gridPos = { h = 1; w = 24; x = 0; y = 0; };
      collapsed = true;  # If applicable
    })

    # Panel 1
    (grafana.mkGauge {
      title = "Panel Title";
      id = 456;
      description = "Panel description";
      gridPos = { h = 4; w = 3; x = 0; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''query expression'';
          legendFormat = "Legend";
          refId = "A";
        })
      ];
    })

    # More panels...
  ];
}
```

## Notes

### Panel Types Supported
- ✅ `row` - Section headers
- ✅ `gauge` - Single gauge panels
- ✅ `stat` - Stat panels (single value displays)
- ✅ `bargauge` - Bar gauge panels (multiple bars)
- ✅ `timeseries` - Time series graphs

### Features Handled
- Grid positioning and sizing
- Panel descriptions
- Prometheus queries with variables (`$node`, `$job`, etc.)
- Custom thresholds
- Units (percent, bytes, seconds, etc.)
- Field config overrides
- Custom colors and styling
- Multi-line query expressions

### Limitations
- The `default.nix` file is NOT regenerated to preserve manual customizations
- Complex nested field configs may need manual adjustment
- Some advanced panel options may not be fully captured

## Maintenance

When the dashboard JSON is updated:

1. Replace or update `node-exporter-full.json`
2. Run `python 03_generate_all.py`
3. Review the generated files and backups
4. Test the generated Nix configuration
5. Commit the changes if everything looks good

## Troubleshooting

### Import Errors

If you get import errors when running `03_generate_all.py`, ensure you're running it from the `scripts/` directory:

```powershell
cd c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\scripts
python 03_generate_all.py
```

### File Not Found

Verify the paths in the script match your actual file locations:
- JSON dashboard path
- Output directory path

### Encoding Issues

The scripts use UTF-8 encoding. If you encounter encoding issues on Windows, ensure your PowerShell session supports UTF-8:

```powershell
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
```

## Related Files

- `../ANALYSIS.md` - Detailed analysis of the dashboard structure
- `../node-exporter-full.json` - Source dashboard JSON
- `../node-exporter-full/` - Generated Nix files directory
- `../../../../lib/grafana.nix` - Grafana helper functions library

## License

These scripts are part of the nix-config repository and follow the same license.
