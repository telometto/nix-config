{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.hm.security.sops;
in
{
  options.hm.security.sops = {
    enable = lib.mkEnableOption "SOPS secrets management for home-manager";

    defaultSymlinkPath = lib.mkOption {
      type = lib.types.str;
      default = "%r/secrets";
      description = "Default path for SOPS secret symlinks; %r resolves to the user's runtime directory.";
    };

    ageSshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
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
      defaultSopsFormat = "yaml";
      inherit (cfg) defaultSymlinkPath;
      defaultSecretsMountPoint = "%r/secrets.d";
      inherit (cfg) secrets;

      age = {
        sshKeyPaths = cfg.ageSshKeyPaths;
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      };
    };
  };
}
