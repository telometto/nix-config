"""
Utility Script - Compare and Validate

This script provides utilities to compare generated Nix files with the JSON source
and validate that all panels are correctly represented.
"""

import json
from pathlib import Path
from typing import Dict, List, Any, Tuple
from importlib import import_module

# Import our modules
extract_panels_module = import_module('01_extract_panels')
DashboardParser = extract_panels_module.DashboardParser


class DashboardValidator:
    """Validates that Nix files correctly represent the JSON dashboard."""
    
    def __init__(self, json_path: str, nix_dir: str):
        """Initialize validator."""
        self.json_path = Path(json_path)
        self.nix_dir = Path(nix_dir)
        self.parser = DashboardParser(str(json_path))
        self.sections = self.parser.extract_sections()
    
    def get_panel_count_by_section(self) -> Dict[str, int]:
        """Get panel count for each section from JSON."""
        counts = {}
        for section in self.sections:
            title = section['row'].get('title', 'Unknown')
            counts[title] = len(section['panels'])
        return counts
    
    def get_panel_ids_by_section(self) -> Dict[str, List[int]]:
        """Get list of panel IDs for each section."""
        ids = {}
        for section in self.sections:
            title = section['row'].get('title', 'Unknown')
            panel_ids = [p.get('id') for p in section['panels']]
            ids[title] = sorted(panel_ids)
        return ids
    
    def check_nix_files_exist(self) -> Tuple[List[str], List[str]]:
        """
        Check which expected Nix files exist.
        
        Returns:
            Tuple of (existing_files, missing_files)
        """
        expected_files = [
            'quick-overview.nix',
            'basic-panels.nix',
            'combined-detailed-panels.nix',
            'memory-meminfo-panels.nix',
            'memory-vmstat-panels.nix',
            'system-timesync-panels.nix',
            'system-processes-panels.nix',
            'system-misc-panels.nix',
            'hardware-misc-panels.nix',
            'systemd-panels.nix',
            'storage-disk-panels.nix',
            'storage-filesystem-panels.nix',
            'network-traffic-panels.nix',
            'network-sockstat-panels.nix',
            'network-netstat-panels.nix',
            'node-exporter-panels.nix',
            'default.nix',
        ]
        
        existing = []
        missing = []
        
        for filename in expected_files:
            filepath = self.nix_dir / filename
            if filepath.exists():
                existing.append(filename)
            else:
                missing.append(filename)
        
        return existing, missing
    
    def get_nix_file_info(self, filename: str) -> Dict[str, Any]:
        """
        Get information about a Nix file.
        
        Returns dict with:
        - line_count: Number of lines
        - char_count: Number of characters
        - has_targets: Whether it contains grafana.mkTarget
        - panel_types: List of detected panel types
        """
        filepath = self.nix_dir / filename
        if not filepath.exists():
            return None
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        lines = content.split('\n')
        
        # Detect panel types
        panel_types = []
        if 'grafana.mkRow' in content:
            panel_types.append('row')
        if 'grafana.mkGauge' in content:
            panel_types.append('gauge')
        if 'grafana.mkStat' in content:
            panel_types.append('stat')
        if 'grafana.mkBargauge' in content:
            panel_types.append('bargauge')
        if 'grafana.mkTimeseries' in content:
            panel_types.append('timeseries')
        
        return {
            'line_count': len(lines),
            'char_count': len(content),
            'has_targets': 'grafana.mkTarget' in content,
            'panel_types': panel_types,
            'panel_count_estimate': content.count('(grafana.mk') - 1  # Subtract 1 for the row
        }
    
    def print_validation_report(self):
        """Print a comprehensive validation report."""
        print("=" * 80)
        print("DASHBOARD VALIDATION REPORT")
        print("=" * 80)
        print()
        
        # Check file existence
        print("1. File Existence Check")
        print("-" * 80)
        existing, missing = self.check_nix_files_exist()
        print(f"✅ Existing files: {len(existing)}")
        if missing:
            print(f"❌ Missing files: {len(missing)}")
            for filename in missing:
                print(f"   - {filename}")
        else:
            print("✅ All expected files exist")
        print()
        
        # Panel counts
        print("2. Panel Count Validation")
        print("-" * 80)
        panel_counts = self.get_panel_count_by_section()
        
        section_to_file = {
            "Quick CPU / Mem / Disk": "quick-overview.nix",
            "Basic CPU / Mem / Net / Disk": "basic-panels.nix",
            "CPU / Memory / Net / Disk": "combined-detailed-panels.nix",
            "Memory Meminfo": "memory-meminfo-panels.nix",
            "Memory Vmstat": "memory-vmstat-panels.nix",
            "System Timesync": "system-timesync-panels.nix",
            "System Processes": "system-processes-panels.nix",
            "System Misc": "system-misc-panels.nix",
            "Hardware Misc": "hardware-misc-panels.nix",
            "Systemd": "systemd-panels.nix",
            "Storage Disk": "storage-disk-panels.nix",
            "Storage Filesystem": "storage-filesystem-panels.nix",
            "Network Traffic": "network-traffic-panels.nix",
            "Network Sockstat": "network-sockstat-panels.nix",
            "Network Netstat": "network-netstat-panels.nix",
            "Node Exporter": "node-exporter-panels.nix",
        }
        
        for section_title, expected_count in panel_counts.items():
            filename = section_to_file.get(section_title)
            if filename:
                info = self.get_nix_file_info(filename)
                if info:
                    estimated = info['panel_count_estimate']
                    status = "✅" if estimated == expected_count else "⚠️ "
                    print(f"{status} {section_title}")
                    print(f"    Expected: {expected_count} panels | Estimated: {estimated} panels")
                    print(f"    File: {filename} ({info['line_count']} lines)")
                else:
                    print(f"❌ {section_title}")
                    print(f"    File missing: {filename}")
        print()
        
        # Panel type summary
        print("3. Panel Type Summary")
        print("-" * 80)
        type_counts = self.parser.get_panel_types_summary()
        for panel_type, count in sorted(type_counts.items()):
            print(f"  {panel_type:15s}: {count:3d} panels")
        print()
        
        # Dashboard metadata
        print("4. Dashboard Metadata")
        print("-" * 80)
        dashboard = self.parser.dashboard
        print(f"  Title: {dashboard.get('title')}")
        print(f"  UID: {dashboard.get('uid')}")
        print(f"  Version: {dashboard.get('version')}")
        print(f"  Schema Version: {dashboard.get('schemaVersion')}")
        print(f"  Timezone: {dashboard.get('timezone')}")
        print(f"  Refresh: {dashboard.get('refresh')}")
        print(f"  Total Sections: {len(self.sections)}")
        print(f"  Total Panels: {sum(panel_counts.values())}")
        print()
        
        # Panel IDs check
        print("5. Panel ID Distribution")
        print("-" * 80)
        all_ids = []
        for section in self.sections:
            for panel in section['panels']:
                all_ids.append(panel.get('id'))
        
        unique_ids = set(all_ids)
        if len(all_ids) == len(unique_ids):
            print(f"✅ All panel IDs are unique ({len(all_ids)} panels)")
        else:
            print(f"⚠️  Duplicate panel IDs found!")
            print(f"   Total panels: {len(all_ids)}")
            print(f"   Unique IDs: {len(unique_ids)}")
        print()


class ComparisonTool:
    """Tools for comparing JSON panels with generated Nix code."""
    
    def __init__(self, json_path: str, nix_path: str):
        """Initialize comparison tool."""
        self.json_path = Path(json_path)
        self.nix_path = Path(nix_path)
    
    def extract_panel_titles_from_json(self, section_title: str) -> List[str]:
        """Extract panel titles from a JSON section."""
        parser = DashboardParser(str(self.json_path))
        sections = parser.extract_sections()
        
        for section in sections:
            if section['row'].get('title') == section_title:
                return [p.get('title', 'Unknown') for p in section['panels']]
        
        return []
    
    def extract_panel_titles_from_nix(self, filename: str) -> List[str]:
        """Extract panel titles from a Nix file."""
        filepath = self.nix_path / filename
        if not filepath.exists():
            return []
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Simple regex to find titles
        import re
        pattern = r'title\s*=\s*"([^"]+)"'
        matches = re.findall(pattern, content)
        
        # Filter out the row title (usually the first one)
        if matches:
            return matches[1:]  # Skip first (row title)
        return []
    
    def compare_section(self, section_title: str, filename: str):
        """Compare a section between JSON and Nix."""
        print(f"Comparing: {section_title}")
        print(f"File: {filename}")
        print("-" * 80)
        
        json_titles = self.extract_panel_titles_from_json(section_title)
        nix_titles = self.extract_panel_titles_from_nix(filename)
        
        print(f"JSON panels: {len(json_titles)}")
        print(f"Nix panels: {len(nix_titles)}")
        
        if json_titles == nix_titles:
            print("✅ Panel titles match perfectly!")
        else:
            print("⚠️  Panel titles differ")
            
            # Find differences
            json_set = set(json_titles)
            nix_set = set(nix_titles)
            
            missing = json_set - nix_set
            extra = nix_set - json_set
            
            if missing:
                print(f"\n  Missing in Nix ({len(missing)}):")
                for title in sorted(missing):
                    print(f"    - {title}")
            
            if extra:
                print(f"\n  Extra in Nix ({len(extra)}):")
                for title in sorted(extra):
                    print(f"    + {title}")
        
        print()


def main():
    """Main function."""
    json_path = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full.json"
    nix_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full"
    
    # Run validation
    validator = DashboardValidator(json_path, nix_dir)
    validator.print_validation_report()
    
    print("\n" + "=" * 80)
    print("DETAILED COMPARISON")
    print("=" * 80)
    print()
    
    # Compare a few sections as examples
    comparator = ComparisonTool(json_path, nix_dir)
    
    examples = [
        ("Quick CPU / Mem / Disk", "quick-overview.nix"),
        ("Basic CPU / Mem / Net / Disk", "basic-panels.nix"),
    ]
    
    for section_title, filename in examples:
        comparator.compare_section(section_title, filename)


if __name__ == "__main__":
    main()
