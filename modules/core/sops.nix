# Automatically imported
{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
{
  sops = {
    defaultSopsFile = lib.mkDefault inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = lib.mkDefault "yaml";
    age = {
      sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
      generateKey = lib.mkDefault true;
    };
    secrets = {
      "tokens/gh-ns-test" = { };
      "tokens/github-ns" = { };
      "tokens/gitlab-fa" = { };
      "tokens/gitlab-ns" = { };
      # Legacy secret currently in use for Tailscale
      "general/tsKeyFilePath" = { };
      # Note: add "general/tailscaleAuthKey" later and switch mapping once populated
      "general/borgKeyFilePath" = { };
      "general/borgRepo" = { };
      "general/paperlessKeyFilePath" = {
        # paperless service reads the file; default root:root is fine; 0400
        mode = "0400";
      };
      "general/searxSecretKey" = {
        # searx runs as searx:searx; ensure it can read the secret
        owner = "searx";
        group = "searx";
        mode = "0400";
      };
      # Grafana Cloud secrets
      "grafana_cloud/api_key" = {
        mode = "0400";
      };
      "grafana_cloud/username" = {
        mode = "0400";
      };
      "grafana_cloud/remote_write_url" = {
        mode = "0400";
      };
    };
    templates."access-tokens".content = ''
      access-tokens = "github.com=${config.sops.placeholder."tokens/github-ns"}"

      extra-access-tokens = "github.com=${config.sops.placeholder."tokens/gh-ns-test"}" "gitlab.com=${
        config.sops.placeholder."tokens/gitlab-ns"
      }" "gitlab.com=${config.sops.placeholder."tokens/gitlab-fa"}"
    '';
  };

  # Bridge SOPS -> telometto.secrets (legacy path mapping) as runtime path strings
  telometto.secrets = {
    tsKeyFile = toString config.sops.secrets."general/tsKeyFilePath".path;
    paperlessKeyFile = toString config.sops.secrets."general/paperlessKeyFilePath".path;
    searxSecretKeyFile = toString config.sops.secrets."general/searxSecretKey".path;
    borgKeyFile = toString config.sops.secrets."general/borgKeyFilePath".path;
    borgRepo = toString config.sops.secrets."general/borgRepo".path;
    grafanaCloudApiKeyFile = toString config.sops.secrets."grafana_cloud/api_key".path;
    # Username & URL: Read as strings (not sensitive, needed for config generation)
    # Remove trailing newlines that SOPS adds when storing values
    grafanaCloudUsername = lib.removeSuffix "\n" (builtins.readFile config.sops.secrets."grafana_cloud/username".path);
    grafanaCloudRemoteWriteUrl = lib.removeSuffix "\n" (builtins.readFile config.sops.secrets."grafana_cloud/remote_write_url".path);
  };

  environment.systemPackages = [
    pkgs.age
    pkgs.sops
  ];
}
