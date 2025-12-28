# Automatically imported
{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
let
  # Helper: only include secrets/config when condition is true
  whenEnabled = condition: attrs: lib.optionalAttrs condition attrs;

  # Service enablement checks
  hasTailscale = config.services.tailscale.enable or false;
  hasBorg = config.services.borgbackup.jobs != { };
  hasPaperless = config.services.paperless.enable or false;
  hasSearx = config.services.searx.enable or false;
  hasGrafanaCloud = config.telometto.services.grafanaCloud.enable or false;
  hasCloudflared = config.telometto.services.cloudflared.enable or false;
  hasCrowdsec = config.services.crowdsec.enable or false;
  hasCloudflareAccessIpUpdater = config.telometto.services.cloudflareAccessIpUpdater.enable or false;
  hasInfluxdb = config.telometto.services.influxdb.enable or false;
  hasInfluxdbRemoteWrite = config.telometto.services.influxdbRemoteWrite.enable or false;

  # Host-specific checks
  isKaizer = config.networking.hostName == "kaizer";
  isBlizzard = config.networking.hostName == "blizzard";
  isSnowfall = config.networking.hostName == "snowfall";
  isAvalanche = config.networking.hostName == "avalanche";
in

{
  sops = {
    defaultSopsFile = lib.mkDefault inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = lib.mkDefault "yaml";
    age = {
      sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
      generateKey = lib.mkDefault true;
    };

    # Secrets: only defined when their corresponding service is enabled
    secrets =
      # Base secrets (always available for nix commands, git auth, etc.)
      {
        "system/hashedPw" = { };
        "tokens/github-ns" = { };
        "tokens/gitlab-fa" = { };
        "tokens/gitlab-ns" = { };
      }
      # Service-specific secrets
      // whenEnabled hasTailscale {
        "general/tsKeyFilePath" = { };
      }
      // whenEnabled (hasTailscale && isKaizer) {
        "external/kaizer_tsKey" = { };
      }
      // whenEnabled hasBorg {
        "general/borgKeyFilePath" = { };
        "general/borgRepo" = { };
      }
      // whenEnabled hasPaperless {
        "general/paperlessKeyFilePath" = { };
      }
      // whenEnabled hasSearx {
        "general/searxSecretKey" = { };
      }
      // whenEnabled hasGrafanaCloud {
        "grafana/cloud/api_key" = { };
        "grafana/cloud/username" = { };
        "grafana/cloud/remote_write_url" = { };
      }
      // whenEnabled (hasCloudflared && isBlizzard) {
        "cloudflare/blizzard_creds" = { };
      }
      // whenEnabled (hasCloudflared && isSnowfall) {
        "cloudflare/snowfall_creds" = { };
      }
      // whenEnabled hasCrowdsec {
        "crowdsec/traefik_bouncer" = {
          mode = "0775";
        };
        "crowdsec/firewall_bouncer" = { };
        "crowdsec/console_token" = { };
      }
      // whenEnabled hasCloudflareAccessIpUpdater {
        "cloudflare/access_api_token" = { };
      }
      # InfluxDB server needs both password and token
      // whenEnabled hasInfluxdb {
        "influxdb/password" = { };
        "influxdb/token" = { };
      }
      # Remote hosts only need the token for authentication
      // whenEnabled (hasInfluxdbRemoteWrite && !hasInfluxdb) {
        "influxdb/token" = { };
      };

    # Templates for combining secrets (only created when needed)
    templates = {
      "access-tokens".content = ''
        access-tokens = "github.com=${config.sops.placeholder."tokens/github-ns"}"

        extra-access-tokens = "gitlab.com=${config.sops.placeholder."tokens/gitlab-ns"}" "gitlab.com=${
          config.sops.placeholder."tokens/gitlab-fa"
        }"
      '';
    }
    // whenEnabled hasGrafanaCloud {
      "grafana-cloud-config".content = ''
        GRAFANA_CLOUD_USERNAME=${config.sops.placeholder."grafana/cloud/username"}
        GRAFANA_CLOUD_REMOTE_WRITE_URL=${config.sops.placeholder."grafana/cloud/remote_write_url"}
      '';
    };
  };

  # Bridge SOPS -> telometto.secrets (legacy path mapping) as runtime path strings
  # Only expose paths for secrets that are actually defined
  telometto.secrets =
    whenEnabled hasTailscale {
      tsKeyFile = toString config.sops.secrets."general/tsKeyFilePath".path;
    }
    // whenEnabled (hasTailscale && isKaizer) {
      kaizerTsKey = toString config.sops.secrets."external/kaizer_tsKey".path;
    }
    // whenEnabled hasPaperless {
      paperlessKeyFile = toString config.sops.secrets."general/paperlessKeyFilePath".path;
    }
    // whenEnabled hasSearx {
      searxSecretKeyFile = toString config.sops.secrets."general/searxSecretKey".path;
    }
    // whenEnabled hasBorg {
      borgKeyFile = toString config.sops.secrets."general/borgKeyFilePath".path;
      borgRepo = toString config.sops.secrets."general/borgRepo".path;
    }
    // whenEnabled hasGrafanaCloud {
      grafanaCloudApiKeyFile = toString config.sops.secrets."grafana/cloud/api_key".path;
      grafanaCloudUsername = toString config.sops.secrets."grafana/cloud/username".path;
      grafanaCloudRemoteWriteUrl = toString config.sops.secrets."grafana/cloud/remote_write_url".path;
    }
    // whenEnabled hasCloudflared (
      if isBlizzard then
        {
          cloudflaredCredentialsFile = toString config.sops.secrets."cloudflare/blizzard_creds".path;
        }
      else if isSnowfall then
        {
          cloudflaredCredentialsFile = toString config.sops.secrets."cloudflare/snowfall_creds".path;
        }
      else
        { }
    )
    // whenEnabled hasCrowdsec {
      crowdsecTraefikBouncerTokenFile = toString config.sops.secrets."crowdsec/traefik_bouncer".path;
      crowdsecFirewallBouncerTokenFile = toString config.sops.secrets."crowdsec/firewall_bouncer".path;
      crowdsecConsoleTokenFile = toString config.sops.secrets."crowdsec/console_token".path;
    }
    // whenEnabled hasCloudflareAccessIpUpdater {
      cloudflareAccessApiTokenFile = toString config.sops.secrets."cloudflare/access_api_token".path;
    }
    # InfluxDB server gets both password and token
    // whenEnabled hasInfluxdb {
      influxdbPasswordFile = toString config.sops.secrets."influxdb/password".path;
      influxdbTokenFile = toString config.sops.secrets."influxdb/token".path;
    }
    # Remote write hosts only need the token
    // whenEnabled (hasInfluxdbRemoteWrite && !hasInfluxdb) {
      influxdbTokenFile = toString config.sops.secrets."influxdb/token".path;
    };

  environment.systemPackages = [
    pkgs.age
    pkgs.sops
  ];
}
