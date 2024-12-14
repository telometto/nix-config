{ config, lib, pkgs, VARS, ... }:

{
  services.gpg-agent = {
    sshKeys = [ ];

    extraConfig = ''
      allow-preset-passphrase
    '';
  };
}
