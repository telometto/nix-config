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
    };

    secrets = { };
}
