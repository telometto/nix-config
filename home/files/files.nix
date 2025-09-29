{ lib, config, ... }:
let
  cfg = config.hm.files;

  # User-defined SSH hosts - no defaults, full user control
  allSshHosts = cfg.sshConfig.hosts; # Generate SSH config block for a single host
  renderSshHost =
    hostPattern: hostConfig:
    let
      configLines = lib.mapAttrsToList (key: value: "  ${key} ${value}") hostConfig;
    in
    ''
      Host ${hostPattern}
      ${lib.concatStringsSep "\n" configLines}'';

  # Generate the complete SSH config
  sshConfigText = lib.concatStringsSep "\n\n" (lib.mapAttrsToList renderSshHost allSshHosts) + "\n";

in
{
  options.hm.files = {
    enable = lib.mkEnableOption "Home directory file management";

    sshConfig = {
      enable = lib.mkEnableOption "Manage SSH configuration files";

      hosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        description = "SSH host configurations. Users define host names and their options.";
        example = {
          "*" = {
            ForwardAgent = "yes";
            AddKeysToAgent = "yes";
            Compression = "yes";
          };
          "github-personal" = {
            Hostname = "ssh.github.com";
            Port = "443";
            User = "git";
            IdentityFile = "~/.ssh/github-key";
          };
          "my-server" = {
            Hostname = "example.com";
            User = "myuser";
            Port = "2222";
          };
        };
      };

      allowedSigners = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "SSH allowed signers for commit signature verification";
        example = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE user@example.com"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... another@example.com"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mkIf cfg.sshConfig.enable (
      {
        ".ssh/config".text = sshConfigText;
      }
      // lib.optionalAttrs (cfg.sshConfig.allowedSigners != [ ]) {
        ".ssh/allowed_signers".text = lib.concatStringsSep "\n" cfg.sshConfig.allowedSigners + "\n";
      }
    );
  };
}
