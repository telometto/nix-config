{ config, lib, pkgs, myVars, ... }:
let
  PATH = config.sops.defaultSymlinkPath;
in
{
  sops = {
    # defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFile = ../../../../nix-secrets/secrets/secrets.yaml;
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
      "users/admin/username" = { path = "${PATH}/users/admin/username"; };
      "users/admin/description" = { path = "${PATH}/users/admin/description"; };

      "users/luke/username" = { path = "${PATH}/users/luke/username"; };
      "users/luke/description" = { path = "${PATH}/users/luke/description"; };
      "users/frankie/username" = { path = "${PATH}/users/frankie/username"; };
      "users/frankie/description" = { path = "${PATH}/users/frankie/description"; };
      "users/wife/username" = { path = "${PATH}/users/wife/username"; };
      "users/wife/description" = { path = "${PATH}/users/wife/description"; };

      ## Devices
      "desktop/hostname" = { path = "${PATH}/desktop/hostname"; };
      "desktop/hostId" = { path = "${PATH}/desktop/hostId"; };

      "laptop/hostname" = { path = "${PATH}/laptop/hostname"; };
      "laptop/hostId" = { path = "${PATH}/laptop/hostId"; };

      "server/hostname" = { path = "${PATH}/server/hostname"; };
      "server/hostId" = { path = "${PATH}/server/hostId"; };

      ## General
      "general/tsKeyFilePath" = { path = "${PATH}/general/tsKeyFilePath"; };
      "general/paperlessKeyFilePath" = { path = "${PATH}/general/paperlessKeyFilePath"; };
      "general/borgKeyFilePath" = { path = "${PATH}/general/borgKeyFilePath"; };
      "general/borgRshFilePath" = { path = "${PATH}/general/borgRshFilePath"; };
      "general/borgRepo" = { path = "${PATH}/general/borgRepo"; };
      "general/testPath" = { path = "${PATH}/general/testPath"; };
      "general/plexDataDir" = { path = "${PATH}/general/plexDataDir"; };
      "general/crowdsecApiKey" = { path = "${PATH}/general/crowdsecApiKey"; };
      "general/sshPubKey" = { path = "${PATH}/general/sshPubKey"; };
      "general/gpgSshPubKey" = { path = "${PATH}/general/gpgSshPubKey"; };
      "general/searxSecretKey" = { path = "${PATH}/general/searxSecretKey"; };
      "general/wireguardKeyFile" = { path = "${PATH}/general/wireguardKeyFile"; };

      ## Tokens
      "tokens/github-rl" = { };
      "tokens/github-ns" = { };
      "tokens/gitlab-fa" = { };
      "tokens/gitlab-ns" = { };

      # Git
      "git/github-prim-email" = { path = "${PATH}/git/github-prim-email"; };
      "git/github-email" = { path = "${PATH}/git/github-email"; };
      "git/github-signingkey" = { path = "${PATH}/git/github-signingkey"; };
      "git/gitlab-email" = { path = "${PATH}/git/gitlab-email"; };
      "git/gitlab-signingkey" = { path = "${PATH}/git/gitlab-signingkey"; };
    };
  };
}
