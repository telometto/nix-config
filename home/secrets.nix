{ config, lib, pkgs, inputs, VARS, ... }:

{
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";

    age = {
      sshKeyPaths = [
        "${config.home.homeDirectory}/.ssh/id_ed25519"
        "${config.home.homeDirectory}/.ssh/sops-hm-blizzard"
        "${config.home.homeDirectory}/.ssh/zeno-avalanche"
      ];

      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = true; # Automatically generate age key if it doesn't exist
    };

    # gnupg = {
    #   home = "${config.home.homeDirectory}/.gnupg";
    #   sshKeyPaths = [
    #     # "${config.home.homeDirectory}/.ssh/id_rsa"
    #     # "${config.home.homeDirectory}/.ssh/id_ed25519"
    #   ];
    # };

    secrets = {
      # User secrets
      "users/admin/username" = { };
      "users/admin/description" = { };

      # General secrets
      "general/tsKeyFilePath" = { };

      # Tokens
      "tokens/github-ns" = { };
      "tokens/gitlab-ns" = { };
      ## Users
      # "users/admin/username" = { path = "${config.sops.defaultSymlinkPath}/users/admin/username"; };
      # "users/admin/description" = { path = "${config.sops.defaultSymlinkPath}/users/admin/description"; };

      # "users/luke/username" = { path = "${config.sops.defaultSymlinkPath}/users/luke/username"; };
      # "users/luke/description" = { path = "${config.sops.defaultSymlinkPath}/users/luke/description"; };
      # "users/frankie/username" = { path = "${config.sops.defaultSymlinkPath}/users/frankie/username"; };
      # "users/frankie/description" = { path = "${config.sops.defaultSymlinkPath}/users/frankie/description"; };
      # "users/wife/username" = { path = "${config.sops.defaultSymlinkPath}/users/wife/username"; };
      # "users/wife/description" = { path = "${config.sops.defaultSymlinkPath}/users/wife/description"; };

      ## Devices
      # "desktop/hostname" = { path = "${config.sops.defaultSymlinkPath}/desktop/hostname"; };
      # "desktop/hostId" = { path = "${config.sops.defaultSymlinkPath}/desktop/hostId"; };

      # "laptop/hostname" = { path = "${config.sops.defaultSymlinkPath}/laptop/hostname"; };
      # "laptop/hostId" = { path = "${config.sops.defaultSymlinkPath}/laptop/hostId"; };

      # "server/hostname" = { path = "${config.sops.defaultSymlinkPath}/server/hostname"; };
      # "server/hostId" = { path = "${config.sops.defaultSymlinkPath}/server/hostId"; };

      ## General
      # "general/tsKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/tsKeyFilePath"; };
      # "general/paperlessKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/paperlessKeyFilePath"; };
      # "general/borgKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/borgKeyFilePath"; };
      # "general/borgRepo" = { path = "${config.sops.defaultSymlinkPath}/general/borgRepo"; };
      # "general/testPath" = { path = "${config.sops.defaultSymlinkPath}/general/testPath"; };
      # "general/plexDataDir" = { path = "${config.sops.defaultSymlinkPath}/general/plexDataDir"; };
      # "general/crowdsecApiKey" = { path = "${config.sops.defaultSymlinkPath}/general/crowdsecApiKey"; };
      # "general/sshPubKey" = { path = "${config.sops.defaultSymlinkPath}/general/sshPubKey"; };
      # "general/gpgSshPubKey" = { path = "${config.sops.defaultSymlinkPath}/general/gpgSshPubKey"; };
      # "general/searxSecretKey" = { path = "${config.sops.defaultSymlinkPath}/general/searxSecretKey"; };
      # "general/wireguardKeyFile" = { path = "${config.sops.defaultSymlinkPath}/general/wireguardKeyFile"; };

      ## Tokens
      # "tokens/github-rl" = { path = "${config.sops.defaultSymlinkPath}/tokens/github-rl"; };
      # "tokens/github-ns" = { path = "${config.sops.defaultSymlinkPath}/tokens/github-ns"; };
      # "tokens/gitlab-fa" = { path = "${config.sops.defaultSymlinkPath}/tokens/gitlab-fa"; };
      # "tokens/gitlab-ns" = { path = "${config.sops.defaultSymlinkPath}/tokens/gitlab-ns"; };

      # Git
      # "git/github-prim-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-prim-email"; };
      # "git/github-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-email"; };
      # "git/github-signingkey" = { path = "${config.sops.defaultSymlinkPath}/git/github-signingkey"; };
      # "git/gitlab-email" = { path = "${config.sops.defaultSymlinkPath}/git/gitlab-email"; };
      # "git/gitlab-signingkey" = { path = "${config.sops.defaultSymlinkPath}/git/gitlab-signingkey"; };
    };

    # templates."access-tokens".content = ''
    #   access-tokens =
    #     github.com=${config.sops.placeholder."tokens/github-rl"}
    #     github.com=${config.sops.placeholder."tokens/github-ns"}
    #     gitlab.com=${config.sops.placeholder."tokens/gitlab-fa"}
    #     gitlab.com=${config.sops.placeholder."tokens/gitlab-ns"}
    # '';
  };
}
