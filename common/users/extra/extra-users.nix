# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.extraUsers = {
    ${myVars.users.wife.user} = {
      isNormalUser = myVars.users.wife.isNormalUser;
      description = myVars.users.wife.description;
      extraGroups = myVars.users.wife.extraGroups;
      hashedPassword = myVars.users.wife.hashedPassword;
      shell = pkgs.zsh;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        myVars.users.admin.sshPubKey
        myVars.users.admin.gpgSshPubKey
      ];
    };

    ${myVars.users.luke.user} = {
      isNormalUser = myVars.users.luke.isNormalUser;
      description = myVars.users.luke.description;
      extraGroups = myVars.users.luke.extraGroups;
      hashedPassword = myVars.users.luke.hashedPassword;
      shell = pkgs.zsh;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        myVars.users.admin.sshPubKey
        myVars.users.admin.gpgSshPubKey
      ];
    };

    ${myVars.users.frankie.user} = {
      isNormalUser = myVars.users.frankie.isNormalUser;
      description = myVars.users.frankie.description;
      extraGroups = myVars.users.frankie.extraGroups;
      hashedPassword = myVars.users.frankie.hashedPassword;
      shell = pkgs.zsh;

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
