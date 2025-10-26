# telometto.secrets.*: central secrets options
# Define stable, project-owned options to reference secrets throughout modules.
{ lib, ... }:
{
  options.telometto.secrets = {
    # Tailscale auth key file path (resolved from SOPS centrally)
    tsKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string (do not coerce into store)
      default = null;
      description = ''
        Path to the Tailscale auth key file. This is resolved from SOPS in core/sops.nix
        so feature modules can consume it without referencing SOPS directly.
      '';
    };

    # Paperless admin password file path (resolved from SOPS centrally)
    paperlessKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the Paperless-ngx admin password file. Mapped from SOPS in core/sops.nix.
      '';
    };

    # Searx server secret key file path (resolved from SOPS centrally)
    # Note: Keep this as a runtime path string to avoid leaking secrets to the Nix store.
    searxSecretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Searx secret key. Mapped from SOPS in core/sops.nix.
      '';
    };

    # BorgBackup password file path (resolved from SOPS centrally)
    borgKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Borg repository passphrase. Mapped from SOPS in core/sops.nix.
      '';
    };

    # Optional: Borg repository URL (if prefer not to hard-code in host config)
    borgRepo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Borg repository URL. If null, set per-host under telometto.services.borgbackup.jobs.<name>.repo.
        If provided here, hosts can reference config.telometto.secrets.borgRepo.
      '';
    };

    # Grafana Cloud credentials (resolved from SOPS centrally)
    grafanaCloudApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Grafana Cloud API key. Mapped from SOPS in core/sops.nix.
      '';
    };

    grafanaCloudUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Grafana Cloud username (Instance ID). Resolved from SOPS in core/sops.nix.
      '';
    };

    grafanaCloudRemoteWriteUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Grafana Cloud Prometheus remote write endpoint URL. Resolved from SOPS in core/sops.nix.
      '';
    };

    # Kubernetes Firefox credentials (resolved from SOPS centrally)
    firefoxUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Firefox username for Kubernetes deployment. Resolved from SOPS in core/sops.nix.
      '';
    };

    firefoxPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Firefox password for Kubernetes deployment. Resolved from SOPS in core/sops.nix.
      '';
    };

    # Cloudflare Tunnel credentials (resolved from SOPS centrally)
    cloudflaredCredentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the Cloudflare Tunnel credentials file. Mapped from SOPS in core/sops.nix.
      '';
    };

    # CrowdSec LAPI bouncer token (resolved from SOPS centrally)
    crowdsecLapiTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the CrowdSec LAPI bouncer token. Used by Traefik bouncer plugin.
        Mapped from SOPS in core/sops.nix.
      '';
    };

    # CrowdSec Console enrollment token (resolved from SOPS centrally)
    crowdsecConsoleTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the CrowdSec Console enrollment token. Used for web dashboard.
        Mapped from SOPS in core/sops.nix.
      '';
    };
  };
}
