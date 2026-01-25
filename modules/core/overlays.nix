{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.sys.overlays;

  # Helper to create an overlay that pulls a package from a different nixpkgs input
  mkOverlayFromInput =
    inputName: packageNames:
    let
      input = inputs.${inputName} or (throw "Input '${inputName}' not found in flake inputs");
      pkgs = import input {
        system = config.nixpkgs.system or "x86_64-linux";
        inherit (config.nixpkgs) config;
      };
    in
    final: prev:
    lib.listToAttrs (
      map (pkgName: {
        name = pkgName;
        value = pkgs.${pkgName} or (throw "Package '${pkgName}' not found in input '${inputName}'");
      }) packageNames
    );

  # Generate overlays from the configured package mappings
  generatedOverlays = lib.flatten (
    lib.mapAttrsToList (inputName: packageNames: [
      (mkOverlayFromInput inputName packageNames)
    ]) cfg.fromInputs
  );
in
{
  options.sys.overlays = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the sys overlay system";
    };

    fromInputs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Pull specific packages from different flake inputs.

        Example:
        ```nix
        sys.overlays.fromInputs = {
          nixpkgs-unstable = [ "firefox" "chromium" ];
          nixpkgs-stable = [ "vscode" ];
        };
        ```

        This will override the specified packages with versions from the specified inputs.
      '';
      example = lib.literalExpression ''
        {
          nixpkgs-unstable = [ "firefox" "discord" ];
          nixpkgs-stable = [ "thunderbird" ];
        }
      '';
    };

    custom = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = ''
        List of custom overlay functions to apply.

        Example:
        ```nix
        sys.overlays.custom = [
          (final: prev: {
            myPackage = prev.myPackage.override { enableFeature = true; };
          })
        ];
        ```
      '';
      example = lib.literalExpression ''
        [
          (final: prev: {
            firefox = prev.firefox.override { enablePlasmaBrowserIntegration = true; };
          })
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = generatedOverlays ++ cfg.custom;
  };
}
