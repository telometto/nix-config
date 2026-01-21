{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sys.programs.githubPackages;

  packageOptions = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this GitHub package";

      src = lib.mkOption {
        type = lib.types.package;
        description = "Source derivation (usually from fetchFromGitHub)";
      };

      pname = lib.mkOption {
        type = lib.types.str;
        description = "Package name";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = "unstable";
        description = "Package version";
      };

      buildInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Build-time dependencies";
      };

      nativeBuildInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Native build-time dependencies";
      };

      propagatedBuildInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Runtime dependencies that should be propagated";
      };

      buildPhase = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Custom build phase";
      };

      installPhase = lib.mkOption {
        type = lib.types.lines;
        description = "Custom install phase";
      };

      meta = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Package metadata (description, homepage, license, etc.)";
      };

      extraDerivationArgs = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional arguments to pass to mkDerivation";
      };
    };
  };

  buildGithubPackage =
    name: pkgCfg:
    pkgs.stdenv.mkDerivation (
      {
        inherit (pkgCfg)
          pname
          version
          src
          buildInputs
          nativeBuildInputs
          propagatedBuildInputs
          meta
          ;

        buildPhase = lib.optionalString (pkgCfg.buildPhase != "") pkgCfg.buildPhase;
        installPhase = pkgCfg.installPhase;
      }
      // pkgCfg.extraDerivationArgs
    );

  enabledPackages = lib.filterAttrs (_: pkg: pkg.enable) cfg.packages;
  builtPackages = lib.mapAttrs buildGithubPackage enabledPackages;
in
{
  options.sys.programs.githubPackages = {
    packages = lib.mkOption {
      type = lib.types.attrsOf packageOptions;
      default = { };
      description = "GitHub packages to install";
    };
  };

  config = lib.mkIf (builtPackages != { }) {
    environment.systemPackages = lib.attrValues builtPackages;
  };
}
