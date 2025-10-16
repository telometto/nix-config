"""
Nix Code Generation Script

This script converts JSON panel definitions into Nix code using the
grafana helper functions from lib/grafana.nix.
"""

import json
from typing import Dict, List, Any, Optional
from pathlib import Path


class NixCodeGenerator:
    """Generates Nix code from Grafana panel JSON definitions."""
    
    def __init__(self, indent_size: int = 2):
        """Initialize the code generator."""
        self.indent_size = indent_size
        self.indent_level = 0
    
    def indent(self, text: str = "") -> str:
        """Return indented text."""
        spaces = " " * (self.indent_level * self.indent_size)
        if text:
            return f"{spaces}{text}"
        return spaces
    
    def format_string(self, s: str) -> str:
        """Format a string for Nix, handling special characters."""
        # Check if string contains special characters that need ''
        if '\n' in s or '"' in s or '$' in s:
            # Use Nix multi-line string syntax
            return f"''{s}''"
        else:
            # Simple string
            return f'"{s}"'
    
    def format_value(self, value: Any) -> str:
        """Format a Python value as Nix code."""
        if value is None:
            return "null"
        elif isinstance(value, bool):
            return "true" if value else "false"
        elif isinstance(value, (int, float)):
            return str(value)
        elif isinstance(value, str):
            return self.format_string(value)
        elif isinstance(value, list):
            if not value:
                return "[ ]"
            # Check if it's a simple list
            if all(isinstance(v, (str, int, float, bool)) for v in value):
                items = " ".join(self.format_value(v) for v in value)
                return f"[ {items} ]"
            else:
                # Complex list
                return self.format_list(value)
        elif isinstance(value, dict):
            return self.format_dict(value)
        else:
            return str(value)
    
    def format_list(self, items: List[Any]) -> str:
        """Format a list as Nix code."""
        if not items:
            return "[ ]"
        
        lines = ["["]
        self.indent_level += 1
        for item in items:
            lines.append(self.indent(self.format_value(item)))
        self.indent_level -= 1
        lines.append(self.indent("]"))
        return "\n".join(lines)
    
    def format_dict(self, d: Dict[str, Any]) -> str:
        """Format a dictionary as Nix attribute set."""
        if not d:
            return "{ }"
        
        lines = ["{"]
        self.indent_level += 1
        for key, value in d.items():
            formatted_value = self.format_value(value)
            lines.append(self.indent(f"{key} = {formatted_value};"))
        self.indent_level -= 1
        lines.append(self.indent("}"))
        return "\n".join(lines)
    
    def generate_target(self, target: Dict[str, Any]) -> str:
        """Generate Nix code for a Prometheus target/query."""
        expr = target.get('expr', '')
        legend = target.get('legendFormat', '')
        ref_id = target.get('refId', 'A')
        instant = target.get('instant', True)
        
        # Handle multi-line expressions
        if '\n' in expr or len(expr) > 80:
            expr_formatted = self.format_string(expr)
        else:
            expr_formatted = self.format_string(expr)
        
        lines = ["(grafana.mkTarget {"]
        self.indent_level += 1
        lines.append(self.indent(f"expr = {expr_formatted};"))
        lines.append(self.indent(f"legendFormat = {self.format_string(legend)};"))
        lines.append(self.indent(f'refId = "{ref_id}";'))
        if not instant:
            lines.append(self.indent("instant = false;"))
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_grid_pos(self, grid_pos: Dict[str, int]) -> str:
        """Generate Nix code for gridPos."""
        return f"{{ h = {grid_pos['h']}; w = {grid_pos['w']}; x = {grid_pos['x']}; y = {grid_pos['y']}; }}"
    
    def generate_field_config_override(self, override: Dict[str, Any]) -> str:
        """Generate Nix code for a field config override."""
        lines = ["{"]
        self.indent_level += 1
        
        # Matcher
        matcher = override.get('matcher', {})
        if matcher:
            lines.append(self.indent("matcher = {"))
            self.indent_level += 1
            lines.append(self.indent(f'id = "{matcher.get("id", "")}";'))
            options = matcher.get('options')
            if isinstance(options, str):
                lines.append(self.indent(f'options = "{options}";'))
            else:
                lines.append(self.indent(f"options = {self.format_value(options)};"))
            self.indent_level -= 1
            lines.append(self.indent("};"))
        
        # Properties
        properties = override.get('properties', [])
        if properties:
            lines.append(self.indent("properties = ["))
            self.indent_level += 1
            for prop in properties:
                lines.append(self.indent("{"))
                self.indent_level += 1
                lines.append(self.indent(f'id = "{prop.get("id", "")}";'))
                prop_value = prop.get('value')
                lines.append(self.indent(f"value = {self.format_value(prop_value)};"))
                self.indent_level -= 1
                lines.append(self.indent("}"))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        self.indent_level -= 1
        lines.append(self.indent("}"))
        return "\n".join(lines)
    
    def generate_field_config(self, field_config: Dict[str, Any]) -> str:
        """Generate Nix code for fieldConfig parameter."""
        if not field_config:
            return ""
        
        # Check if there are custom settings beyond defaults
        overrides = field_config.get('overrides', [])
        defaults_custom = field_config.get('defaults', {}).get('custom', {})
        
        if not overrides and not defaults_custom:
            return ""
        
        lines = ["fieldConfig = {"]
        self.indent_level += 1
        
        # Overrides
        if overrides:
            lines.append(self.indent("overrides = ["))
            self.indent_level += 1
            for override in overrides:
                override_code = self.generate_field_config_override(override)
                lines.extend(self.indent(line) if line else "" for line in override_code.split('\n'))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        # Defaults custom settings
        if defaults_custom:
            lines.append(self.indent("defaults = {"))
            self.indent_level += 1
            lines.append(self.indent("custom = {"))
            self.indent_level += 1
            for key, value in defaults_custom.items():
                lines.append(self.indent(f"{key} = {self.format_value(value)};"))
            self.indent_level -= 1
            lines.append(self.indent("};"))
            self.indent_level -= 1
            lines.append(self.indent("};"))
        
        self.indent_level -= 1
        lines.append(self.indent("};"))
        return "\n".join(lines)
    
    def generate_row(self, row: Dict[str, Any]) -> str:
        """Generate Nix code for a row panel."""
        title = row.get('title', 'Untitled')
        panel_id = row.get('id', 0)
        grid_pos = row.get('gridPos', {})
        collapsed = row.get('collapsed', False)
        
        lines = ["(grafana.mkRow {"]
        self.indent_level += 1
        lines.append(self.indent(f'title = "{title}";'))
        lines.append(self.indent(f"id = {panel_id};"))
        lines.append(self.indent(f"gridPos = {self.generate_grid_pos(grid_pos)};"))
        if collapsed:
            lines.append(self.indent("collapsed = true;"))
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_gauge(self, panel: Dict[str, Any]) -> str:
        """Generate Nix code for a gauge panel."""
        title = panel.get('title', 'Untitled')
        panel_id = panel.get('id', 0)
        description = panel.get('description', '')
        grid_pos = panel.get('gridPos', {})
        targets = panel.get('targets', [])
        
        # Extract unit from fieldConfig
        unit = panel.get('fieldConfig', {}).get('defaults', {}).get('unit', 'percent')
        
        # Extract custom thresholds if present
        thresholds = panel.get('fieldConfig', {}).get('defaults', {}).get('thresholds')
        
        lines = ["(grafana.mkGauge {"]
        self.indent_level += 1
        lines.append(self.indent(f'title = "{title}";'))
        lines.append(self.indent(f"id = {panel_id};"))
        lines.append(self.indent(f'description = {self.format_string(description)};'))
        lines.append(self.indent(f"gridPos = {self.generate_grid_pos(grid_pos)};"))
        
        # Thresholds (if custom)
        if thresholds:
            lines.append(self.indent(f"thresholds = {self.format_value(thresholds)};"))
        
        # Unit (if not default)
        if unit != 'percent':
            lines.append(self.indent(f'unit = "{unit}";'))
        
        # Targets
        if targets:
            lines.append(self.indent("targets = ["))
            self.indent_level += 1
            for target in targets:
                target_code = self.generate_target(target)
                lines.extend(self.indent(line) if line else "" for line in target_code.split('\n'))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_stat(self, panel: Dict[str, Any]) -> str:
        """Generate Nix code for a stat panel."""
        title = panel.get('title', 'Untitled')
        panel_id = panel.get('id', 0)
        description = panel.get('description', '')
        grid_pos = panel.get('gridPos', {})
        targets = panel.get('targets', [])
        
        # Extract unit and decimals from fieldConfig
        defaults = panel.get('fieldConfig', {}).get('defaults', {})
        unit = defaults.get('unit', 'short')
        decimals = defaults.get('decimals', 0)
        
        lines = ["(grafana.mkStat {"]
        self.indent_level += 1
        lines.append(self.indent(f'title = "{title}";'))
        lines.append(self.indent(f"id = {panel_id};"))
        if description:
            lines.append(self.indent(f'description = {self.format_string(description)};'))
        lines.append(self.indent(f"gridPos = {self.generate_grid_pos(grid_pos)};"))
        
        if unit != 'short':
            lines.append(self.indent(f'unit = "{unit}";'))
        if decimals != 0:
            lines.append(self.indent(f"decimals = {decimals};"))
        
        # Targets
        if targets:
            lines.append(self.indent("targets = ["))
            self.indent_level += 1
            for target in targets:
                target_code = self.generate_target(target)
                lines.extend(self.indent(line) if line else "" for line in target_code.split('\n'))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_bargauge(self, panel: Dict[str, Any]) -> str:
        """Generate Nix code for a bargauge panel."""
        title = panel.get('title', 'Untitled')
        panel_id = panel.get('id', 0)
        description = panel.get('description', '')
        grid_pos = panel.get('gridPos', {})
        targets = panel.get('targets', [])
        
        lines = ["(grafana.mkBargauge {"]
        self.indent_level += 1
        lines.append(self.indent(f'title = "{title}";'))
        lines.append(self.indent(f"id = {panel_id};"))
        lines.append(self.indent(f'description = {self.format_string(description)};'))
        lines.append(self.indent(f"gridPos = {self.generate_grid_pos(grid_pos)};"))
        
        # Targets
        if targets:
            lines.append(self.indent("targets = ["))
            self.indent_level += 1
            for target in targets:
                target_code = self.generate_target(target)
                lines.extend(self.indent(line) if line else "" for line in target_code.split('\n'))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_timeseries(self, panel: Dict[str, Any]) -> str:
        """Generate Nix code for a timeseries panel."""
        title = panel.get('title', 'Untitled')
        panel_id = panel.get('id', 0)
        description = panel.get('description', '')
        grid_pos = panel.get('gridPos', {})
        targets = panel.get('targets', [])
        field_config = panel.get('fieldConfig', {})
        
        # Extract unit from fieldConfig
        unit = field_config.get('defaults', {}).get('unit', 'short')
        
        lines = ["(grafana.mkTimeseries {"]
        self.indent_level += 1
        lines.append(self.indent(f'title = "{title}";'))
        lines.append(self.indent(f"id = {panel_id};"))
        lines.append(self.indent(f'description = {self.format_string(description)};'))
        lines.append(self.indent(f"gridPos = {self.generate_grid_pos(grid_pos)};"))
        
        if unit != 'short':
            lines.append(self.indent(f'unit = "{unit}";'))
        
        # Targets
        if targets:
            lines.append(self.indent("targets = ["))
            self.indent_level += 1
            for target in targets:
                target_code = self.generate_target(target)
                lines.extend(self.indent(line) if line else "" for line in target_code.split('\n'))
            self.indent_level -= 1
            lines.append(self.indent("];"))
        
        # Field config (if there are overrides or custom settings)
        field_config_code = self.generate_field_config(field_config)
        if field_config_code:
            lines.extend(self.indent(line) if line else "" for line in field_config_code.split('\n'))
        
        self.indent_level -= 1
        lines.append(self.indent("})"))
        
        return "\n".join(lines)
    
    def generate_panel(self, panel: Dict[str, Any]) -> str:
        """Generate Nix code for any panel type."""
        panel_type = panel.get('type', 'unknown')
        
        if panel_type == 'row':
            return self.generate_row(panel)
        elif panel_type == 'gauge':
            return self.generate_gauge(panel)
        elif panel_type == 'stat':
            return self.generate_stat(panel)
        elif panel_type == 'bargauge':
            return self.generate_bargauge(panel)
        elif panel_type == 'timeseries':
            return self.generate_timeseries(panel)
        else:
            return f"# Unknown panel type: {panel_type}"
    
    def generate_section_file(self, section: Dict[str, Any]) -> str:
        """Generate complete Nix file for a section."""
        row = section['row']
        panels = section['panels']
        title = row.get('title', 'Untitled Section')
        
        lines = ['{ lib, grafana }:', '', '{', '  panels = [']
        
        # Generate row
        self.indent_level = 2
        row_code = self.generate_row(row)
        lines.extend(self.indent(line) if line else "" for line in row_code.split('\n'))
        lines.append("")
        
        # Generate panels
        for panel in panels:
            panel_code = self.generate_panel(panel)
            lines.extend(self.indent(line) if line else "" for line in panel_code.split('\n'))
            lines.append("")
        
        lines.append('  ];')
        lines.append('}')
        lines.append('')  # Final newline
        
        return '\n'.join(lines)


def main():
    """Main function to demonstrate usage."""
    print("Nix Code Generator - Demo")
    print("=" * 80)
    
    # Example: Generate code for a simple gauge panel
    gauge_panel = {
        "id": 20,
        "title": "CPU Busy",
        "description": "Overall CPU busy percentage",
        "type": "gauge",
        "gridPos": {"h": 4, "w": 3, "x": 3, "y": 1},
        "fieldConfig": {
            "defaults": {
                "unit": "percent"
            }
        },
        "targets": [
            {
                "expr": "100 * (1 - avg(rate(node_cpu_seconds_total{mode=\"idle\", instance=\"$node\"}[5m])))",
                "legendFormat": "",
                "refId": "A",
                "instant": True
            }
        ]
    }
    
    generator = NixCodeGenerator()
    code = generator.generate_panel(gauge_panel)
    
    print("Generated Nix code for gauge panel:")
    print("-" * 80)
    print(code)
    print()


if __name__ == "__main__":
    main()
