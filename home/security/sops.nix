{ lib, config, pkgs, inputs, ... }:
let cfg = config.hm.security.sops;
in {
  options.hm.security.sops = {
    enable = lib.mkEnableOption "SOPS secrets management for home-manager";

    defaultSymlinkPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/user/1000/secrets";
      description = "Default path for SOPS secret symlinks";
    };

    ageSshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH key paths for Age";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "SOPS secrets configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
      defaultSopsFormat = "yaml"; # Default format for sops files
      defaultSymlinkPath = cfg.defaultSymlinkPath;
      defaultSecretsMountPoint = "/run/user/1000/secrets.d";
      secrets = cfg.secrets;

      age = {
        sshKeyPaths = cfg.ageSshKeyPaths;
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      };
    };
  };
}
