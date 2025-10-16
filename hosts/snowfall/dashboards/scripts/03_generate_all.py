"""
Main Orchestration Script

This script orchestrates the complete process of:
1. Parsing the node-exporter-full.json dashboard
2. Extracting sections and panels
3. Generating Nix code for each section
4. Writing the Nix files to the appropriate locations
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any

# Import our helper modules - using importlib to handle numbered filenames
from importlib import import_module

# Dynamically import the modules
extract_panels_module = import_module('01_extract_panels')
generate_nix_module = import_module('02_generate_nix')

DashboardParser = extract_panels_module.DashboardParser
NixCodeGenerator = generate_nix_module.NixCodeGenerator


# Mapping of section titles to Nix filenames
SECTION_TO_FILENAME = {
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


class DashboardNixGenerator:
    """Main class to orchestrate the dashboard to Nix conversion."""
    
    def __init__(
        self,
        json_path: str,
        output_dir: str,
        backup_existing: bool = True
    ):
        """
        Initialize the generator.
        
        Args:
            json_path: Path to the node-exporter-full.json file
            output_dir: Directory where Nix files should be written
            backup_existing: Whether to backup existing files before overwriting
        """
        self.json_path = Path(json_path)
        self.output_dir = Path(output_dir)
        self.backup_existing = backup_existing
        
        self.parser = DashboardParser(str(self.json_path))
        self.generator = NixCodeGenerator(indent_size=2)
        
        # Statistics
        self.stats = {
            'sections_processed': 0,
            'panels_generated': 0,
            'files_written': 0,
            'files_backed_up': 0,
            'errors': []
        }
    
    def backup_file(self, filepath: Path) -> bool:
        """
        Backup an existing file by appending .backup to its name.
        
        Returns True if backup was created, False otherwise.
        """
        if not filepath.exists():
            return False
        
        backup_path = filepath.with_suffix(filepath.suffix + '.backup')
        
        # If backup already exists, add a number
        counter = 1
        while backup_path.exists():
            backup_path = filepath.with_suffix(f"{filepath.suffix}.backup{counter}")
            counter += 1
        
        try:
            import shutil
            shutil.copy2(filepath, backup_path)
            self.stats['files_backed_up'] += 1
            return True
        except Exception as e:
            self.stats['errors'].append(f"Failed to backup {filepath}: {e}")
            return False
    
    def generate_section_file(self, section: Dict[str, Any], filename: str) -> bool:
        """
        Generate a Nix file for a section.
        
        Args:
            section: Section data with row and panels
            filename: Target filename for the Nix file
            
        Returns True if successful, False otherwise.
        """
        try:
            # Generate Nix code
            nix_code = self.generator.generate_section_file(section)
            
            # Prepare output path
            output_path = self.output_dir / filename
            
            # Backup existing file if requested
            if self.backup_existing and output_path.exists():
                self.backup_file(output_path)
            
            # Write the file
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(nix_code)
            
            self.stats['files_written'] += 1
            self.stats['panels_generated'] += len(section['panels'])
            
            return True
            
        except Exception as e:
            self.stats['errors'].append(
                f"Failed to generate {filename}: {e}"
            )
            return False
    
    def generate_all_sections(self) -> bool:
        """
        Generate Nix files for all sections in the dashboard.
        
        Returns True if all sections were processed successfully.
        """
        # Extract sections from the dashboard
        sections = self.parser.extract_sections()
        
        print(f"Found {len(sections)} sections to process")
        print("=" * 80)
        
        success = True
        
        for section in sections:
            title = section['row'].get('title', 'Unknown')
            filename = SECTION_TO_FILENAME.get(title)
            
            if filename is None:
                error_msg = f"No filename mapping for section: {title}"
                self.stats['errors'].append(error_msg)
                print(f"❌ {error_msg}")
                success = False
                continue
            
            print(f"Processing: {title}")
            print(f"  → {filename} ({len(section['panels'])} panels)")
            
            if self.generate_section_file(section, filename):
                print(f"  ✅ Generated successfully")
                self.stats['sections_processed'] += 1
            else:
                print(f"  ❌ Failed to generate")
                success = False
            
            print()
        
        return success
    
    def generate_default_nix(self) -> bool:
        """
        Generate the default.nix file that imports all section files.
        
        This creates the main dashboard definition file.
        """
        try:
            sections = self.parser.extract_sections()
            
            # Build the imports list
            imports = []
            for section in sections:
                title = section['row'].get('title', 'Unknown')
                filename = SECTION_TO_FILENAME.get(title)
                if filename:
                    # Convert filename to variable name
                    var_name = filename.replace('-panels.nix', 'Panels').replace('.nix', '').replace('-', '')
                    if var_name.endswith('Panels'):
                        pass  # Keep as is
                    elif var_name == 'quickoverview':
                        var_name = 'quickOverview'
                    else:
                        var_name = var_name + 'Panels'
                    
                    imports.append((var_name, filename))
            
            # Get dashboard metadata
            dashboard = self.parser.dashboard
            
            lines = [
                '{ lib, pkgs }:',
                '',
                'let',
                '  grafana = import ../../../../lib/grafana.nix { inherit lib; };',
                '',
                '  # Import panel modules'
            ]
            
            # Add imports
            for var_name, filename in imports:
                lines.append(f'  {var_name} = import ./{filename} {{ inherit lib grafana; }};')
            
            lines.extend([
                '',
                '  # Dashboard variables for datasource and node selection',
                '  variables = ['
            ])
            
            # Add variables
            variables = dashboard.get('templating', {}).get('list', [])
            for var in variables:
                lines.append('    {')
                # Add variable properties
                for key, value in var.items():
                    if isinstance(value, dict):
                        lines.append(f'      {key} = {{')
                        for k, v in value.items():
                            if isinstance(v, str):
                                lines.append(f'        {k} = "{v}";')
                            else:
                                lines.append(f'        {k} = {str(v).lower() if isinstance(v, bool) else v};')
                        lines.append('      };')
                    elif isinstance(value, list):
                        lines.append(f'      {key} = [ ];')
                    elif isinstance(value, str):
                        lines.append(f'      {key} = "{value}";')
                    elif isinstance(value, bool):
                        lines.append(f'      {key} = {str(value).lower()};')
                    elif isinstance(value, int):
                        lines.append(f'      {key} = {value};')
                    elif value is None:
                        lines.append(f'      {key} = null;')
                lines.append('    }')
            
            lines.extend([
                '  ];',
                '',
                '  # Dashboard links',
                '  links = ['
            ])
            
            # Add links
            links = dashboard.get('links', [])
            for link in links:
                lines.append('    {')
                for key, value in link.items():
                    if isinstance(value, str):
                        lines.append(f'      {key} = "{value}";')
                    elif isinstance(value, bool):
                        lines.append(f'      {key} = {str(value).lower()};')
                    elif isinstance(value, list):
                        lines.append(f'      {key} = [ ];')
                lines.append('    }')
            
            lines.extend([
                '  ];',
                '',
                '  # Combine all panels',
                '  allPanels = lib.flatten ['
            ])
            
            # Add panel references
            for var_name, _ in imports:
                lines.append(f'    {var_name}.panels')
            
            lines.extend([
                '  ];',
                '',
                'in',
                'grafana.mkDashboard {',
                f'  title = "{dashboard.get("title", "Node Exporter Full")}";',
                f'  uid = "{dashboard.get("uid", "")}";',
                f'  tags = [ "linux" ];',
                '  panels = allPanels;',
                '  inherit variables links;',
                '}',
                ''
            ])
            
            # Write the file
            output_path = self.output_dir / 'default.nix'
            
            if self.backup_existing and output_path.exists():
                self.backup_file(output_path)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(lines))
            
            print("✅ Generated default.nix")
            return True
            
        except Exception as e:
            error_msg = f"Failed to generate default.nix: {e}"
            self.stats['errors'].append(error_msg)
            print(f"❌ {error_msg}")
            return False
    
    def print_summary(self):
        """Print a summary of the generation process."""
        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Sections processed: {self.stats['sections_processed']}")
        print(f"Panels generated: {self.stats['panels_generated']}")
        print(f"Files written: {self.stats['files_written']}")
        print(f"Files backed up: {self.stats['files_backed_up']}")
        
        if self.stats['errors']:
            print(f"\n⚠️  Errors encountered: {len(self.stats['errors'])}")
            for error in self.stats['errors']:
                print(f"  - {error}")
        else:
            print("\n✅ All sections processed successfully!")
    
    def run(self):
        """Run the complete generation process."""
        print("Dashboard to Nix Generator")
        print("=" * 80)
        print(f"Input: {self.json_path}")
        print(f"Output: {self.output_dir}")
        print(f"Backup existing: {self.backup_existing}")
        print()
        
        # Generate section files
        success = self.generate_all_sections()
        
        # Generate default.nix
        # Note: Commenting this out as we want to preserve the existing default.nix
        # which may have manual customizations
        # success = success and self.generate_default_nix()
        
        # Print summary
        self.print_summary()
        
        return success


def main():
    """Main entry point."""
    # Configuration
    json_path = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full.json"
    output_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full"
    
    # Create generator
    generator = DashboardNixGenerator(
        json_path=json_path,
        output_dir=output_dir,
        backup_existing=True
    )
    
    # Run the generation
    success = generator.run()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
