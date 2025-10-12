{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.programs.python-venv;
in
{
  options.telometto.programs.python-venv = {
    enable = lib.mkEnableOption "Python virtual environment support with nix-ld";

    pythonPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3;
      description = "The Python package to wrap for venv support";
      example = lib.literalExpression "pkgs.python311";
    };

    extraPythonPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Python packages to include in the environment";
      example = lib.literalExpression "[ pkgs.python3Packages.pip pkgs.python3Packages.virtualenv ]";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure nix-ld is enabled for library support
    assertions = [
      {
        assertion = config.programs.nix-ld.enable || config.telometto.programs.nix-ld.enable;
        message = ''
          Python venv support requires nix-ld to be enabled.
          Either enable programs.nix-ld.enable or telometto.programs.nix-ld.enable.
        '';
      }
    ];

    # Install Python with a wrapper that sets LD_LIBRARY_PATH from NIX_LD_LIBRARY_PATH
    # This allows pip-installed packages with compiled binaries to work correctly
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "python" ''
        export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        exec ${cfg.pythonPackage}/bin/python "$@"
      '')
      (pkgs.writeShellScriptBin "python3" ''
        export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        exec ${cfg.pythonPackage}/bin/python3 "$@"
      '')
    ]
    ++ cfg.extraPythonPackages;
  };
}
