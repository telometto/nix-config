{ config, lib, pkgs, inputs, myVars, ... }:
# let
#   PATH = config.sops.defaultSymlinkPath;
# in
{
  sops = {
    # defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile; #"${inputs.nix-secrets.secrets.secretsFile}/nix-secrets/secrets/secrets.yaml";
    defaultSopsFormat = "yaml"; # Default format for sops files
    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";

    age = {
      sshKeyPaths = [
        "${config.home.homeDirectory}/.ssh/id_ed25519"
        "${config.home.homeDirectory}/.ssh/sops-home-blizzard"
      ];

      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };

    # gnupg = {
    #   home = "${config.home.homeDirectory}/.gnupg";
    #   sshKeyPaths = [
    #     # "${config.home.homeDirectory}/.ssh/id_rsa"
    #     # "${config.home.homeDirectory}/.ssh/id_ed25519"
    #   ];
    # };

    secrets = {
      ## Users
      "users/admin/username" = { path = "${config.sops.defaultSymlinkPath}/users/admin/username"; };
      "users/admin/description" = { path = "${config.sops.defaultSymlinkPath}/users/admin/description"; };

      "users/luke/username" = { path = "${config.sops.defaultSymlinkPath}/users/luke/username"; };
      "users/luke/description" = { path = "${config.sops.defaultSymlinkPath}/users/luke/description"; };
      "users/frankie/username" = { path = "${config.sops.defaultSymlinkPath}/users/frankie/username"; };
      "users/frankie/description" = { path = "${config.sops.defaultSymlinkPath}/users/frankie/description"; };
      "users/wife/username" = { path = "${config.sops.defaultSymlinkPath}/users/wife/username"; };
      "users/wife/description" = { path = "${config.sops.defaultSymlinkPath}/users/wife/description"; };

      ## Devices
      "desktop/hostname" = { path = "${config.sops.defaultSymlinkPath}/desktop/hostname"; };
      "desktop/hostId" = { path = "${config.sops.defaultSymlinkPath}/desktop/hostId"; };

      "laptop/hostname" = { path = "${config.sops.defaultSymlinkPath}/laptop/hostname"; };
      "laptop/hostId" = { path = "${config.sops.defaultSymlinkPath}/laptop/hostId"; };

      "server/hostname" = { path = "${config.sops.defaultSymlinkPath}/server/hostname"; };
      "server/hostId" = { path = "${config.sops.defaultSymlinkPath}/server/hostId"; };

      ## General
      "general/tsKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/tsKeyFilePath"; };
      "general/paperlessKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/paperlessKeyFilePath"; };
      "general/borgKeyFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/borgKeyFilePath"; };
      "general/borgRshFilePath" = { path = "${config.sops.defaultSymlinkPath}/general/borgRshFilePath"; };
      "general/borgRepo" = { path = "${config.sops.defaultSymlinkPath}/general/borgRepo"; };
      "general/testPath" = { path = "${config.sops.defaultSymlinkPath}/general/testPath"; };
      "general/plexDataDir" = { path = "${config.sops.defaultSymlinkPath}/general/plexDataDir"; };
      "general/crowdsecApiKey" = { path = "${config.sops.defaultSymlinkPath}/general/crowdsecApiKey"; };
      "general/sshPubKey" = { path = "${config.sops.defaultSymlinkPath}/general/sshPubKey"; };
      "general/gpgSshPubKey" = { path = "${config.sops.defaultSymlinkPath}/general/gpgSshPubKey"; };
      "general/searxSecretKey" = { path = "${config.sops.defaultSymlinkPath}/general/searxSecretKey"; };
      "general/wireguardKeyFile" = { path = "${config.sops.defaultSymlinkPath}/general/wireguardKeyFile"; };

      ## Tokens
      "tokens/github-rl" = { path = "${config.sops.defaultSymlinkPath}/tokens/github-rl"; };
      "tokens/github-ns" = { path = "${config.sops.defaultSymlinkPath}/tokens/github-ns"; };
      "tokens/gitlab-fa" = { path = "${config.sops.defaultSymlinkPath}/tokens/gitlab-fa"; };
      "tokens/gitlab-ns" = { path = "${config.sops.defaultSymlinkPath}/tokens/gitlab-ns"; };

      # Git
      "git/github-prim-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-prim-email"; };
      "git/github-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-email"; };
      # "git/github-signingkey" = { path = "${config.sops.defaultSymlinkPath}/git/github-signingkey"; };
      "git/gitlab-email" = { path = "${config.sops.defaultSymlinkPath}/git/gitlab-email"; };
      # "git/gitlab-signingkey" = { path = "${config.sops.defaultSymlinkPath}/git/gitlab-signingkey"; };
    };
  };
}
