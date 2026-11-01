{ lib, config, ... }:
let
  cfg = config.sys.services.cross-seed;
in
{
  options.sys.services.cross-seed = {
    enable = lib.mkEnableOption "cross-seed";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2468;
      description = "Loopback-only cross-seed API port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cross-seed";
      description = "Persistent cross-seed configuration, database, and output directory.";
    };

    linkDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/cross-seed";
      description = "Hardlink directory on the torrent data filesystem, at the same path in both guests.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The pinned nixpkgs package predates upstream's unsafe-metadata fixes.
    # Overlay both the daemon and the NixOS module's generated defaults.
    # Remove once the primary input provides cross-seed >= 6.13.9.
    nixpkgs.overlays = [
      (_final: prev: {
        cross-seed =
          if lib.versionAtLeast prev.cross-seed.version "6.13.9" then
            prev.cross-seed
          else
            prev.cross-seed.overrideAttrs (
              finalAttrs: _previousAttrs: {
                version = "6.13.9";
                src = prev.fetchFromGitHub {
                  owner = "cross-seed";
                  repo = "cross-seed";
                  tag = "v${finalAttrs.version}";
                  hash = "sha256-8WdSolN/AbW7C7HKrQpA3S+yndYJSq6eQ0/ahqHvHpc=";
                };
                npmDepsHash = "sha256-60YMls10w+PxgNLq2Bl3DXBUt3EWtQL5Zotn/ft+U5E=";
                npmDeps = prev.fetchNpmDeps {
                  name = "cross-seed-${finalAttrs.version}-npm-deps";
                  inherit (finalAttrs) src;
                  hash = finalAttrs.npmDepsHash;
                };
              }
            );
      })
    ];

    assertions = [
      {
        assertion = config.sys.secrets.crossSeedSettingsFile != null;
        message = "sys.services.cross-seed requires sys.secrets.crossSeedSettingsFile (private JSON settings).";
      }
    ];

    services.cross-seed = {
      enable = true;
      configDir = cfg.dataDir;
      useGenConfigDefaults = true;
      settingsFile = config.sys.secrets.crossSeedSettingsFile;
      settings = {
        host = "127.0.0.1";
        inherit (cfg) port;
        useClientTorrents = true;
        torrentDir = null;
        dataDirs = [ ];
        linkDirs = [ cfg.linkDir ];
        linkType = "hardlink";
        linkCategory = "cross-seed-link";
        action = "inject";
        matchMode = "flexible";

        # Add stopped, verify the existing bytes, and resume only at 100%.
        skipRecheck = false;
        autoResumeMaxDownload = 0;
        ignoreNonRelevantFilesToResume = false;

        rssCadence = "30 minutes";
        searchCadence = "1 day";
        searchLimit = 400;
      };
    };

    # Setgid keeps tracker subdirectories accessible to qBittorrent, whose
    # service also belongs to users. Do not recursively change source ownership.
    systemd.tmpfiles.rules = [
      "d ${cfg.linkDir} 2775 cross-seed users -"
    ];

    systemd.services.cross-seed.serviceConfig = {
      SupplementaryGroups = [ "users" ];
      UMask = "0002";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "10s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
    };
  };
}
