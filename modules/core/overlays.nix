{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.telometto.overlays;

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
  options.telometto.overlays = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the telometto overlay system";
    };

    fromInputs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Pull specific packages from different flake inputs.

        Example:
        ```nix
        telometto.overlays.fromInputs = {
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
        telometto.overlays.custom = [
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
    nixpkgs.overlays = generatedOverlays ++ cfg.custom ++ [
      # FIXME: udevil fails to build with GCC 15 due to stricter C standard (gnu23).
      # The signal handler functions use old-style function declarations.
      # Force -std=gnu17 until upstream fixes the issue.
      # See: https://github.com/NixOS/nixpkgs/issues/475579
      (final: prev: {
        udevil = prev.udevil.overrideAttrs (oldAttrs: {
          env = (oldAttrs.env or { }) // {
            NIX_CFLAGS_COMPILE = toString ((oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -std=gnu17");
          };
        });
      })
    ];
  };
}
