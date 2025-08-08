{ config, lib, pkgs, VARS, ... }:

let mylib = import ../../lib { inherit lib VARS; };
in {
  services = {
    gpg-agent = {
      sshKeys = [ ];

      extraConfig = ''
        allow-preset-passphrase
      '';
    };
  };
}
