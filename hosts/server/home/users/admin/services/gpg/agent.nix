{ config, lib, pkgs, VARS, ... }:

{
  services = {
    gpg-agent = {
      sshKeys = [ "727A831B39D2FAC421617C2C203BF5C382E3B60A" ];

      extraConfig = ''
        allow-preset-passphrase
      '';
    };
  };
}
