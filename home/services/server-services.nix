# Server-specific home-manager services
{ config, lib, pkgs, VARS, ... }:

let mylib = import ../../lib { inherit lib VARS; };
in {
  services = {
    gnome-keyring = {
      enable = true;
      # components = [ "secrets" "ssh" ];
    };

    gpg-agent = {
      sshKeys = [ "727A831B39D2FAC421617C2C203BF5C382E3B60A" ];

      extraConfig = ''
        allow-preset-passphrase
      '';
    };
  };
}
