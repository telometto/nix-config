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
  hasK3sDownloadMgmt = config.telometto.services."k3s-download-mgmt".enable or false;
  hasCloudflared = config.telometto.services.cloudflared.enable or false;
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
        "tokens/gh-ns-test" = { };
        "tokens/github-ns" = { };
        "tokens/gitlab-fa" = { };
        "tokens/gitlab-ns" = { };
      }
      # Service-specific secrets
      // whenEnabled hasTailscale {
        "general/tsKeyFilePath" = { };
      }
      // whenEnabled hasBorg {
        "general/borgKeyFilePath" = { };
        "general/borgRepo" = { };
      }
      // whenEnabled hasPaperless {
        "general/paperlessKeyFilePath" = {
          mode = "0400";
        };
      }
      // whenEnabled hasSearx {
        "general/searxSecretKey" = {
          owner = "searx";
          group = "searx";
          mode = "0400";
        };
      }
      // whenEnabled hasGrafanaCloud {
        "grafana_cloud/api_key" = {
          owner = "prometheus";
          group = "prometheus";
          mode = "0400";
        };
        "grafana_cloud/username" = {
          mode = "0400";
        };
        "grafana_cloud/remote_write_url" = {
          mode = "0400";
        };
      }
      // whenEnabled hasK3sDownloadMgmt {
        "kubernetes/ff-user" = {
          mode = "0400";
        };
        "kubernetes/ff-pw" = {
          mode = "0400";
        };
      }
      // whenEnabled hasCloudflared {
        "cloudflare/server_tunnel" = {
          owner = "cloudflared";
          group = "cloudflared";
          mode = "0400";
        };
      };

    # Templates for combining secrets (only created when needed)
    templates = {
      "access-tokens".content = ''
        access-tokens = "github.com=${config.sops.placeholder."tokens/github-ns"}"

        extra-access-tokens = "github.com=${config.sops.placeholder."tokens/gh-ns-test"}" "gitlab.com=${
          config.sops.placeholder."tokens/gitlab-ns"
        }" "gitlab.com=${config.sops.placeholder."tokens/gitlab-fa"}"
      '';
    }
    // whenEnabled hasGrafanaCloud {
      "grafana-cloud-config".content = ''
        GRAFANA_CLOUD_USERNAME=${config.sops.placeholder."grafana_cloud/username"}
        GRAFANA_CLOUD_REMOTE_WRITE_URL=${config.sops.placeholder."grafana_cloud/remote_write_url"}
      '';
    };
  };

  # Bridge SOPS -> telometto.secrets (legacy path mapping) as runtime path strings
  # Only expose paths for secrets that are actually defined
  telometto.secrets =
    whenEnabled hasTailscale {
      tsKeyFile = toString config.sops.secrets."general/tsKeyFilePath".path;
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
      grafanaCloudApiKeyFile = toString config.sops.secrets."grafana_cloud/api_key".path;
      grafanaCloudUsername = toString config.sops.secrets."grafana_cloud/username".path;
      grafanaCloudRemoteWriteUrl = toString config.sops.secrets."grafana_cloud/remote_write_url".path;
    }
    // whenEnabled hasK3sDownloadMgmt {
      firefoxUser = config.sops.placeholder."kubernetes/ff-user";
      firefoxPassword = config.sops.placeholder."kubernetes/ff-pw";
    }
    // whenEnabled hasCloudflared {
      cloudflaredCredentialsFile = toString config.sops.secrets."cloudflare/server_tunnel".path;
    };

  environment.systemPackages = [
    pkgs.age
    pkgs.sops
  ];
}
