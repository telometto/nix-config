"""
Quick Fixes and Updates Utility

This script provides utilities for common maintenance tasks like:
- Updating lib/grafana.nix configuration parameters
- Finding and replacing patterns across all Nix files
- Batch updating panel configurations
"""

import re
from pathlib import Path
from typing import List, Dict, Any


class NixFileUpdater:
    """Utility for batch updating Nix files."""
    
    def __init__(self, nix_dir: str):
        """Initialize updater."""
        self.nix_dir = Path(nix_dir)
    
    def find_nix_files(self, pattern: str = "*.nix") -> List[Path]:
        """Find all Nix files matching the pattern."""
        return list(self.nix_dir.glob(pattern))
    
    def find_in_file(self, filepath: Path, pattern: str, is_regex: bool = False) -> List[Dict[str, Any]]:
        """
        Find pattern occurrences in a file.
        
        Returns list of matches with line numbers and content.
        """
        matches = []
        
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        for line_num, line in enumerate(lines, start=1):
            if is_regex:
                if re.search(pattern, line):
                    matches.append({
                        'line_num': line_num,
                        'content': line.rstrip(),
                        'file': filepath.name
                    })
            else:
                if pattern in line:
                    matches.append({
                        'line_num': line_num,
                        'content': line.rstrip(),
                        'file': filepath.name
                    })
        
        return matches
    
    def find_in_all_files(self, pattern: str, is_regex: bool = False) -> Dict[str, List[Dict[str, Any]]]:
        """Find pattern in all Nix files."""
        results = {}
        
        for filepath in self.find_nix_files():
            matches = self.find_in_file(filepath, pattern, is_regex)
            if matches:
                results[str(filepath)] = matches
        
        return results
    
    def replace_in_file(
        self,
        filepath: Path,
        old_text: str,
        new_text: str,
        backup: bool = True
    ) -> bool:
        """
        Replace text in a file.
        
        Returns True if any replacements were made.
        """
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if old_text not in content:
            return False
        
        # Backup if requested
        if backup:
            backup_path = filepath.with_suffix(filepath.suffix + '.bak')
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(content)
        
        # Replace
        new_content = content.replace(old_text, new_text)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        return True
    
    def replace_in_all_files(
        self,
        old_text: str,
        new_text: str,
        backup: bool = True,
        dry_run: bool = False
    ) -> Dict[str, int]:
        """
        Replace text in all Nix files.
        
        Returns dict mapping filenames to number of replacements.
        """
        results = {}
        
        for filepath in self.find_nix_files():
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            count = content.count(old_text)
            if count > 0:
                results[filepath.name] = count
                
                if not dry_run:
                    self.replace_in_file(filepath, old_text, new_text, backup)
        
        return results
    
    def update_instant_parameter(self, dry_run: bool = False):
        """
        Update instant parameter in mkTarget calls.
        
        By default, queries should use instant=false for timeseries panels.
        """
        print("Updating instant parameter in mkTarget calls...")
        print("-" * 80)
        
        # Pattern for timeseries panels
        pattern = r'grafana\.mkTimeseries'
        
        files_to_check = []
        for filepath in self.find_nix_files():
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if pattern in content:
                files_to_check.append(filepath)
        
        print(f"Found {len(files_to_check)} files with timeseries panels")
        
        # Check if they have instant = true (which should be false)
        results = self.find_in_all_files(r'instant\s*=\s*true', is_regex=True)
        
        if results:
            print(f"\nFound {len(results)} files with instant = true")
            for filepath, matches in results.items():
                print(f"  {Path(filepath).name}: {len(matches)} occurrences")
            
            if not dry_run:
                # Would need more context to fix properly
                print("\nNote: Manual review recommended for instant parameter updates")
        else:
            print("✅ No issues found with instant parameter")
    
    def check_indentation(self) -> Dict[str, List[int]]:
        """Check for inconsistent indentation in Nix files."""
        issues = {}
        
        for filepath in self.find_nix_files():
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            inconsistent_lines = []
            for line_num, line in enumerate(lines, start=1):
                # Check if line starts with spaces but not a multiple of 2
                if line.startswith(' ') and not line.startswith('  '):
                    leading_spaces = len(line) - len(line.lstrip(' '))
                    if leading_spaces % 2 != 0:
                        inconsistent_lines.append(line_num)
            
            if inconsistent_lines:
                issues[filepath.name] = inconsistent_lines
        
        return issues
    
    def print_statistics(self):
        """Print statistics about the Nix files."""
        print("Nix Files Statistics")
        print("=" * 80)
        
        files = self.find_nix_files()
        print(f"Total Nix files: {len(files)}")
        print()
        
        total_lines = 0
        total_panels = 0
        
        print("File Details:")
        print("-" * 80)
        
        for filepath in sorted(files):
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            lines = len(content.split('\n'))
            panels = content.count('(grafana.mk')
            
            total_lines += lines
            total_panels += panels
            
            print(f"{filepath.name:30s} | {lines:4d} lines | {panels:2d} panels")
        
        print("-" * 80)
        print(f"{'Total':30s} | {total_lines:4d} lines | {total_panels:2d} panels")
        print()


def main():
    """Main function."""
    nix_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full"
    
    updater = NixFileUpdater(nix_dir)
    
    print("Dashboard Nix Files - Quick Fixes & Updates")
    print("=" * 80)
    print()
    
    # Print statistics
    updater.print_statistics()
    
    # Check indentation
    print("\nChecking Indentation...")
    print("-" * 80)
    issues = updater.check_indentation()
    if issues:
        print(f"⚠️  Found indentation issues in {len(issues)} files:")
        for filename, lines in issues.items():
            print(f"  {filename}: lines {lines}")
    else:
        print("✅ All files have consistent indentation")
    print()
    
    # Example: Search for a pattern
    print("\nSearching for 'node_cpu_seconds_total'...")
    print("-" * 80)
    results = updater.find_in_all_files('node_cpu_seconds_total')
    if results:
        for filepath, matches in results.items():
            print(f"{Path(filepath).name}: {len(matches)} occurrences")
    print()
    
    # Check instant parameter usage
    updater.update_instant_parameter(dry_run=True)
    print()
    
    print("=" * 80)
    print("Quick Fix Examples:")
    print("-" * 80)
    print()
    print("# Find all gauge panels:")
    print('updater.find_in_all_files("grafana.mkGauge")')
    print()
    print("# Replace a common expression:")
    print('updater.replace_in_all_files("old_expr", "new_expr", dry_run=True)')
    print()
    print("# Update a specific file:")
    print('updater.replace_in_file(Path("quick-overview.nix"), "old", "new")')
    print()


if __name__ == "__main__":
    main()
