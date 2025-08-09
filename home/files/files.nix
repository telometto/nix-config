{ config, lib, pkgs, VARS, ... }:

let
  # Base SSH configuration that all devices share
  baseSshFile = ''
    Host *
      ForwardAgent yes
      AddKeysToAgent yes
      Compression yes
  '';

  # Common allowed signers for desktop/laptop
  commonAllowedSigners =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE 65364211+telometto@users.noreply.github.com";

  # Device-specific SSH additions
  commonSshAdditions = ''

    Host github.com
      Hostname ssh.github.com
      Port 443
      User git
      IdentityFile ${config.home.homeDirectory}/.ssh/github-key

    Host 192.168.*
      IdentityFile ${config.home.homeDirectory}/.ssh/id_ed25519
      IdentitiesOnly yes
      SetEnv TERM=xterm-256color
  '';

  serverSshAdditions = ''

    Host github.com
      Hostname ssh.github.com
      Port 443
      User git
      IdentityFile ${config.home.homeDirectory}/.ssh/zeno-blizzard
  '';
in
{
  base = { };

  # Device-specific SSH configurations
  desktop = {
    ".ssh/config".text = baseSshFile + commonSshAdditions;
    ".ssh/allowed_signers".text = commonAllowedSigners;
  };

  laptop = {
    ".ssh/config".text = baseSshFile + commonSshAdditions;
    ".ssh/allowed_signers".text = commonAllowedSigners;
  };

  server = { ".ssh/config".text = baseSshFile + serverSshAdditions; };
}
