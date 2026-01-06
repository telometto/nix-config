# treefmt-nix configuration
# Documentation: https://github.com/numtide/treefmt-nix
{ ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";

  programs = {
    # Nix formatting
    nixfmt.enable = true;

    # Shell script formatting
    shfmt.enable = true;

    # YAML formatting
    yamlfmt.enable = true;

    # Markdown formatting
    mdformat.enable = true;

    # JSON formatting
    jsonfmt.enable = true;

    # Python formatting and linting
    ruff = {
      enable = true;
      format = true; # Enable ruff format (replaces black)
    };

    # GitHub Actions workflow linting (disabled to avoid shellcheck conflicts)
    # actionlint.enable = true;

    # Spell checking (optional)
    # typos.enable = true;

    # Deadnix - remove dead Nix code (optional)
    # deadnix.enable = true;

    # Statix - Nix linter (optional)
    # statix.enable = true;
  };

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
        includes = [
          "*.sh"
          "*.bash"
        ];
        options = [
          "-i"
          "2" # Use 2-space indentation
          "-ci" # Indent switch cases
          "-sr" # Redirect operators will be followed by a space
        ];
      };

      yamlfmt = {
        includes = [
          "*.yml"
          "*.yaml"
        ];
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
