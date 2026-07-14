{ lib, config, ... }:
let
  cfg = config.hm.files;
in
{
  options.hm.files = {
    enable = lib.mkEnableOption "Home directory file management";

    sshAllowedSigners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH allowed signers for commit signature verification";
      example = [
        ''user@example.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE''
        ''another@example.com namespaces="git" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...''
      ];
    };
  };

  config = lib.mkIf (cfg.enable && cfg.sshAllowedSigners != [ ]) {
    home.file.".ssh/allowed_signers".text =
      lib.concatStringsSep "\n" cfg.sshAllowedSigners + "\n";

    programs.git.settings.gpg.ssh.allowedSignersFile =
      "${config.home.homeDirectory}/.ssh/allowed_signers";
  };
}
