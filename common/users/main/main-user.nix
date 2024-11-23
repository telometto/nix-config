# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users."${myVars.users.admin.user}" = {
    description = myVars.users.admin.description;
    isNormalUser = myVars.users.admin.isNormalUser;
    extraGroups = lib.concatLists myVars.users.admin.extraGroups (lib.mkIf config.networking.hostName == myVars.systems.desktop.hostname [ "openrazer" ]);
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      myVars.users.admin.sshPubKey
      myVars.users.admin.gpgSshPubKey
    ];
  };
}
