# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users = {
    ${myVars.users.wife.user} = {
      isNormalUser = myVars.users.wife.isNormalUser;
      description = myVars.users.wife.description;
      extraGroups = myVars.users.wife.extraGroups;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        myVars.users.admin.sshPubKey
        myVars.users.admin.gpgSshPubKey
      ];
    };

    ${myVars.luke.user} = {
      isNormalUser = myVars.users.luke.isNormalUser;
      description = myVars.users.luke.description;
      extraGroups = myVars.users.luke.extraGroups;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        myVars.users.admin.sshPubKey
        myVars.users.admin.gpgSshPubKey
      ];
    };

    ${myVars.frankie.user} = {
      isNormalUser = myVars.users.frankie.isNormalUser;
      description = myVars.users.frankie.description;
      extraGroups = myVars.users.frankie.extraGroups;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        myVars.users.admin.sshPubKey
        myVars.users.admin.gpgSshPubKey
      ];
    };
  };
}
