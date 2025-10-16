"""
Panel Extraction Script

This script parses the node-exporter-full.json dashboard and extracts
panel definitions organized by row sections.
"""

import json
from typing import Dict, List, Any
from pathlib import Path


class DashboardParser:
    """Parses Grafana dashboard JSON and organizes panels by sections."""
    
    def __init__(self, json_path: str):
        """Initialize parser with JSON file path."""
        self.json_path = Path(json_path)
        self.dashboard = self._load_dashboard()
        self.sections = []
        
    def _load_dashboard(self) -> Dict[str, Any]:
        """Load and parse the dashboard JSON file."""
        with open(self.json_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def extract_sections(self) -> List[Dict[str, Any]]:
        """
        Extract all sections (rows) and their associated panels.
        
        Returns a list of dictionaries, each containing:
        - row: The row panel definition
        - panels: List of panels belonging to this section
        """
        panels = self.dashboard.get('panels', [])
        sections = []
        current_section = None
        
        for panel in panels:
            if panel.get('type') == 'row':
                # Start a new section
                if current_section is not None:
                    sections.append(current_section)
                
                current_section = {
                    'row': panel,
                    'panels': []
                }
            else:
                # Add panel to current section
                if current_section is not None:
                    current_section['panels'].append(panel)
        
        # Don't forget the last section
        if current_section is not None:
            sections.append(current_section)
        
        self.sections = sections
        return sections
    
    def get_section_by_title(self, title: str) -> Dict[str, Any]:
        """Get a specific section by its title."""
        for section in self.sections:
            if section['row'].get('title') == title:
                return section
        return None
    
    def get_section_metadata(self) -> List[Dict[str, str]]:
        """
        Get metadata about all sections.
        
        Returns a list of dictionaries with section information.
        """
        metadata = []
        for section in self.sections:
            row = section['row']
            metadata.append({
                'id': row.get('id'),
                'title': row.get('title'),
                'collapsed': row.get('collapsed', False),
                'y_position': row.get('gridPos', {}).get('y', 0),
                'panel_count': len(section['panels'])
            })
        return metadata
    
    def get_panel_types_summary(self) -> Dict[str, int]:
        """Get a summary of panel types used in the dashboard."""
        type_counts = {}
        for section in self.sections:
            for panel in section['panels']:
                panel_type = panel.get('type', 'unknown')
                type_counts[panel_type] = type_counts.get(panel_type, 0) + 1
        return type_counts
    
    def export_section_to_file(self, section_title: str, output_path: str):
        """Export a specific section's panels to a JSON file."""
        section = self.get_section_by_title(section_title)
        if section is None:
            raise ValueError(f"Section '{section_title}' not found")
        
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(section, f, indent=2)
    
    def export_all_sections(self, output_dir: str):
        """Export all sections to separate JSON files."""
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for section in self.sections:
            title = section['row'].get('title', 'untitled')
            # Create safe filename
            filename = title.lower().replace(' / ', '_').replace(' ', '_') + '.json'
            filepath = output_dir / filename
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(section, f, indent=2)
            
            print(f"Exported: {filename} ({len(section['panels'])} panels)")


def main():
    """Main function to demonstrate usage."""
    # Path to the dashboard JSON
    json_path = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full.json"
    
    # Initialize parser
    parser = DashboardParser(json_path)
    
    # Extract sections
    sections = parser.extract_sections()
    print(f"Found {len(sections)} sections\n")
    
    # Print section metadata
    print("Section Metadata:")
    print("-" * 80)
    metadata = parser.get_section_metadata()
    for meta in metadata:
        collapsed_str = "✓" if meta['collapsed'] else " "
        print(f"[{collapsed_str}] ID:{meta['id']:3d} Y:{meta['y_position']:2d} "
              f"Panels:{meta['panel_count']:2d} - {meta['title']}")
    
    # Print panel type summary
    print("\n" + "=" * 80)
    print("Panel Types Summary:")
    print("-" * 80)
    type_summary = parser.get_panel_types_summary()
    for panel_type, count in sorted(type_summary.items()):
        print(f"  {panel_type:15s}: {count:3d}")
    
    # Export all sections to separate files
    print("\n" + "=" * 80)
    print("Exporting sections to JSON files...")
    print("-" * 80)
    output_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\extracted_sections"
    parser.export_all_sections(output_dir)
    
    print("\n" + "=" * 80)
    print("Dashboard variables:")
    print("-" * 80)
    variables = parser.dashboard.get('templating', {}).get('list', [])
    for var in variables:
        print(f"  ${var.get('name'):15s} - {var.get('label', 'N/A')}")
    
    print("\n" + "=" * 80)
    print("Dashboard info:")
    print("-" * 80)
    print(f"  Title: {parser.dashboard.get('title')}")
    print(f"  UID: {parser.dashboard.get('uid')}")
    print(f"  Timezone: {parser.dashboard.get('timezone')}")
    print(f"  Refresh: {parser.dashboard.get('refresh')}")
    print(f"  Schema Version: {parser.dashboard.get('schemaVersion')}")
    print(f"  Total Panels: {sum(meta['panel_count'] for meta in metadata)}")


if __name__ == "__main__":
    main()
