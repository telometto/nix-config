{ lib, ... }:
{
  options.sys.secrets = {
    tsKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string (do not coerce into store)
      default = null;
      description = ''
        Path to the Tailscale auth key file. This is resolved from SOPS in core/sops.nix
        so feature modules can consume it without referencing SOPS directly.
      '';
    };

    kaizerTsKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the kaizer-specific Tailscale auth key file. This is resolved from SOPS in core/sops.nix
        and is only available on the kaizer host.
      '';
    };

    paperlessKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the Paperless-ngx admin password file. Mapped from SOPS in core/sops.nix.
      '';
    };

    searxSecretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Searx secret key. Mapped from SOPS in core/sops.nix.
      '';
    };

    borgKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Borg repository passphrase. Mapped from SOPS in core/sops.nix.
      '';
    };

    borgRepo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Borg repository URL. If null, set per-host under sys.services.borgbackup.jobs.<name>.repo.
        If provided here, hosts can reference config.sys.secrets.borgRepo.
      '';
    };

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

    cloudflaredCredentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the Cloudflare Tunnel credentials file. Mapped from SOPS in core/sops.nix.
      '';
    };

    crowdsecTraefikBouncerTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the CrowdSec Traefik bouncer token. Used by Traefik bouncer plugin.
        Mapped from SOPS in core/sops.nix.
      '';
    };

    crowdsecFirewallBouncerTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the CrowdSec Firewall bouncer token. Used by firewall bouncer.
        Mapped from SOPS in core/sops.nix.
      '';
    };

    crowdsecConsoleTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the CrowdSec Console enrollment token. Used for web dashboard.
        Mapped from SOPS in core/sops.nix.
      '';
    };

    cloudflareAccessApiTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Cloudflare API token for Access policy updates.
        Used by cloudflare-access-ip-updater service. Mapped from SOPS in core/sops.nix.
      '';
    };

    influxdbPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the InfluxDB admin password. Mapped from SOPS in core/sops.nix.
      '';
    };

    influxdbTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the InfluxDB admin API token. Mapped from SOPS in core/sops.nix.
      '';
    };

    upsmonPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the UPS monitoring password for NUT upsmon. Mapped from SOPS in core/sops.nix.
      '';
    };

    giteaLfsJwtSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Gitea LFS JWT secret for authenticating LFS batch API requests. Mapped from SOPS in core/sops.nix.
      '';
    };

    seaweedfsAccessKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the SeaweedFS S3 access key. Mapped from SOPS in core/sops.nix.
      '';
    };

    seaweedfsSecretAccessKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the SeaweedFS S3 secret access key. Mapped from SOPS in core/sops.nix.
      '';
    };
  };
}
