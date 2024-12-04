{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    # defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile; #"${inputs.nix-secrets.path}/nix-secrets/secrets/secrets.yaml";
    defaultSopsFormat = "yaml"; # Default format for sops files

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # Paths to the host ssh keys
      keyFile = "/var/lib/sops-nix/key.txt"; # Path to the key file
      generateKey = true; # Generate a new key if the keyFile does not exist
    };

    secrets = {
      ## [ON HOLD] Nested secrets in JSON format do no pass manifest validation; see https://github.com/Mic92/sops-nix/issues/604
      ## Start JSON format
      # "users/admins/username" = { };
      # "users/admins/description" = { };
      # "users/admins/password" = { };
      # "users/regulars/luke" = { };
      # "users/regulars/frankie" = { };
      # "users/regulars/wife" = { };
      # "devices/desktop/ = { };
      # "devices/laptop/ = { };
      # "devices/server/ = { };
      # "general/ssh/pubKeys.mainPubKey" = { };
      # "general/gpg/pubKeys.mainSshPubKey" = { };
      # "general/paths/tailscaleKeyFile" = { };
      # "general/paths/paperlessKeyFile" = { };
      # "general/paths/borgKeyFile" = { };
      # "general/paths/testPath" = { };
      # "general/paths/plexDataDir" = { };
      # "general/apiKeys/crowdsec" = { };
      # "general/apiKeys/wireguardPrivKey" = { };
      # "general/repos/borgRepo" = { };
      # "general/passwords/searxSecretKey" = { };
      # "general/tokens/github.nix-secrets" = { };
      # "general/tokens/github.rate-limit" = { };
      # "general/tokens/gitlab.nix-secrets" = { };
      # "general/tokens/gitlab.full-access" = { };

      # Start YAML format
      "users/admin/username" = { };
      "users/admin/description" = { };

      "users/luke/username" = { };
      "users/luke/description" = { };
      "users/frankie/username" = { };
      "users/frankie/description" = { };
      "users/wife/username" = { };
      "users/wife/description" = { };

      "desktop/hostname" = { };
      "desktop/hostId" = { };

      "laptop/hostname" = { };
      "laptop/hostId" = { };

      "server/hostname" = { };
      "server/hostId" = { };

      "general/tsKeyFilePath" = { };
      "general/paperlessKeyFilePath" = { };
      "general/borgKeyFilePath" = { };
      "general/borgRepo" = { };
      "general/plexDataDir" = { };
      "general/testPath" = { };
      "general/crowdsecApiKey" = { };
      "general/sshPubKey" = { };
      "general/gpgSshPubKey" = { };
      "general/searxSecretKey" = { };
      "general/wireguardKeyFile" = { };

      "tokens/github-rl" = { };
      "tokens/github-ns" = { };
      "tokens/gitlab-fa" = { };
      "tokens/gitlab-ns" = { };

      "git/github-prim-email" = { };
      "git/github-email" = { };
      # "git/github-signingkey" = { };
      "git/gitlab-email" = { };
      # "git/gitlab-signingkey" = { };
    };

    templates."access-tokens".content = ''
      access-tokens = "github.com=${config.sops.placeholder."tokens/github-ns"}"

      extra-access-tokens = "github.com=${config.sops.placeholder."tokens/github-rl"}" "gitlab.com=${config.sops.placeholder."tokens/gitlab-ns"}" "gitlab.com=${config.sops.placeholder."tokens/gitlab-fa"}"
    '';
  };

  environment.systemPackages = with pkgs; [
    age
    sops
  ];
}
