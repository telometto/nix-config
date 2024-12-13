{ config, lib, pkgs, VARS, ... }:

{
  services = {
    gnome-keyring = {
      enable = true;
      # components = [ "secrets" "ssh" ];
    };
  };
}
