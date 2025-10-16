"""
Dashboard Tools - Master Script

This script provides a menu interface to all dashboard generation and maintenance tools.
"""

import sys
from pathlib import Path
from importlib import import_module


def print_header():
    """Print the header."""
    print()
    print("=" * 80)
    print(" " * 20 + "GRAFANA DASHBOARD TOOLS")
    print("=" * 80)
    print()


def print_menu():
    """Print the main menu."""
    print("Available Tools:")
    print("-" * 80)
    print("1. Extract Panels - Parse JSON and export sections")
    print("2. Generate Nix Code - Convert JSON panels to Nix code")
    print("3. Generate All Files - Complete regeneration of all Nix files")
    print("4. Validate Dashboard - Compare JSON with Nix files")
    print("5. Quick Fixes - Batch updates and pattern replacements")
    print("6. View Statistics - Show file and panel statistics")
    print()
    print("0. Exit")
    print("-" * 80)


def run_extract_panels():
    """Run the extract panels script."""
    print("\n" + "=" * 80)
    print("EXTRACT PANELS")
    print("=" * 80 + "\n")
    
    try:
        extract_module = import_module('01_extract_panels')
        extract_module.main()
    except Exception as e:
        print(f"❌ Error running extract panels: {e}")
        import traceback
        traceback.print_exc()


def run_generate_nix():
    """Run the generate Nix code demo."""
    print("\n" + "=" * 80)
    print("GENERATE NIX CODE - DEMO")
    print("=" * 80 + "\n")
    
    try:
        generate_module = import_module('02_generate_nix')
        generate_module.main()
    except Exception as e:
        print(f"❌ Error running generate Nix: {e}")
        import traceback
        traceback.print_exc()


def run_generate_all():
    """Run the complete generation script."""
    print("\n" + "=" * 80)
    print("GENERATE ALL NIX FILES")
    print("=" * 80 + "\n")
    
    print("⚠️  This will regenerate all Nix panel files!")
    print("    Existing files will be backed up with .backup extension")
    print()
    
    confirm = input("Continue? (yes/no): ").strip().lower()
    if confirm not in ['yes', 'y']:
        print("Cancelled.")
        return
    
    try:
        generate_all_module = import_module('03_generate_all')
        generate_all_module.main()
    except Exception as e:
        print(f"❌ Error running generate all: {e}")
        import traceback
        traceback.print_exc()


def run_validate():
    """Run the validation script."""
    print("\n" + "=" * 80)
    print("VALIDATE DASHBOARD")
    print("=" * 80 + "\n")
    
    try:
        validate_module = import_module('04_validate')
        validate_module.main()
    except Exception as e:
        print(f"❌ Error running validation: {e}")
        import traceback
        traceback.print_exc()


def run_quick_fixes():
    """Run the quick fixes script."""
    print("\n" + "=" * 80)
    print("QUICK FIXES")
    print("=" * 80 + "\n")
    
    try:
        fixes_module = import_module('05_quick_fixes')
        fixes_module.main()
    except Exception as e:
        print(f"❌ Error running quick fixes: {e}")
        import traceback
        traceback.print_exc()


def run_statistics():
    """Show statistics about the dashboard and Nix files."""
    print("\n" + "=" * 80)
    print("DASHBOARD STATISTICS")
    print("=" * 80 + "\n")
    
    try:
        # Import required modules
        extract_module = import_module('01_extract_panels')
        fixes_module = import_module('05_quick_fixes')
        
        json_path = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full.json"
        nix_dir = r"c:\Users\agostino.montanaro\Downloads\.versioncontrol\personal\nix-config\hosts\snowfall\dashboards\node-exporter-full"
        
        # Parse dashboard
        parser = extract_module.DashboardParser(json_path)
        sections = parser.extract_sections()
        
        # Print JSON dashboard stats
        print("JSON Dashboard:")
        print("-" * 80)
        metadata = parser.get_section_metadata()
        print(f"Total Sections: {len(sections)}")
        print(f"Total Panels: {sum(meta['panel_count'] for meta in metadata)}")
        print()
        
        type_summary = parser.get_panel_types_summary()
        print("Panel Types:")
        for panel_type, count in sorted(type_summary.items()):
            print(f"  {panel_type:15s}: {count:3d}")
        print()
        
        # Print Nix files stats
        updater = fixes_module.NixFileUpdater(nix_dir)
        updater.print_statistics()
        
    except Exception as e:
        print(f"❌ Error showing statistics: {e}")
        import traceback
        traceback.print_exc()


def main():
    """Main menu loop."""
    # Change to scripts directory if needed
    script_dir = Path(__file__).parent
    if Path.cwd() != script_dir:
        import os
        os.chdir(script_dir)
    
    while True:
        print_header()
        print_menu()
        
        choice = input("Select an option (0-6): ").strip()
        
        if choice == '0':
            print("\nGoodbye!")
            break
        elif choice == '1':
            run_extract_panels()
        elif choice == '2':
            run_generate_nix()
        elif choice == '3':
            run_generate_all()
        elif choice == '4':
            run_validate()
        elif choice == '5':
            run_quick_fixes()
        elif choice == '6':
            run_statistics()
        else:
            print("\n❌ Invalid option. Please try again.")
        
        if choice != '0':
            input("\nPress Enter to continue...")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user. Goodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
