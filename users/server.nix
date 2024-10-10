# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:
let
  vars = import ../vars/vars.nix;
in
{
  users.users."${vars.serverUser}" = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = [ "wheel" "networkmanager" "libvirtd" ];

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      "${vars.openSSHPubKey}"
      "${vars.openSSHGPGPubKey}"
    ];
  };
}
