# treefmt-nix configuration
# Documentation: https://github.com/numtide/treefmt-nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";

  # Nix formatting
  programs.nixfmt.enable = true;

  # Shell script formatting
  programs.shfmt.enable = true;

  # YAML formatting
  programs.yamlfmt.enable = true;

  # Markdown formatting
  programs.mdformat.enable = true;

  # JSON formatting
  programs.jsonfmt.enable = true;

  # GitHub Actions workflow linting (disabled to avoid shellcheck conflicts)
  # programs.actionlint.enable = true;

  # Spell checking (optional)
  # programs.typos.enable = true;

  # Deadnix - remove dead Nix code (optional)
  # programs.deadnix.enable = true;

  # Statix - Nix linter (optional) 
  # programs.statix.enable = true;

  settings = {
    # Global excludes
    global.excludes = [
      # Ignore build artifacts and cache directories
      "result*"
      ".direnv/"
      
      # Ignore lock files that shouldn't be formatted
      "*.lock"
      
      # Ignore GitHub Actions workflows to prevent permission issues
      ".github/workflows/*.yml"
      ".github/workflows/*.yaml"
      
      # Ignore binary files
      "*.png"
      "*.jpg"
      "*.jpeg"
      "*.gif"
      "*.ico"
      "*.svg"
      "*.pdf"
      
      # Ignore theme files that might have specific formatting
      "**/*.theme.css"
      
      # Ignore secrets and keys
      "*.key"
      "*.pem"
      "*.crt"
    ];

    # Formatter-specific settings
    formatter = {
      nixfmt = {
        # Include all Nix files
        includes = [ "*.nix" ];
        excludes = [
          # Exclude generated files or files with special formatting requirements
        ];
      };

      shfmt = {
        # Shell script formatting options
        includes = [ "*.sh" "*.bash" ];
        options = [
          "-i" "2"    # Use 2-space indentation
          "-ci"       # Indent switch cases
          "-sr"       # Redirect operators will be followed by a space
        ];
      };

      yamlfmt = {
        includes = [ "*.yml" "*.yaml" ];
        excludes = [
          # GitHub Actions workflows might have specific formatting needs
          # ".github/workflows/*.yml"
        ];
      };

      mdformat = {
        includes = [ "*.md" ];
        excludes = [
          # Exclude files that might have special markdown formatting
        ];
      };

      # actionlint = {
      #   includes = [ ".github/workflows/*.yml" ".github/workflows/*.yaml" ];
      # };
    };
  };
}
