# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers = {
    ${VARS.users.wife.user} = {
      isNormalUser = VARS.users.wife.isNormalUser;
      description = VARS.users.wife.description;
      extraGroups = VARS.users.wife.extraGroups;
      hashedPassword = VARS.users.wife.hashedPassword;
      shell = pkgs.zsh;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        VARS.users.admin.sshPubKey
        VARS.users.admin.gpgSshPubKey
      ];
    };

    ${VARS.users.luke.user} = {
      isNormalUser = VARS.users.luke.isNormalUser;
      description = VARS.users.luke.description;
      extraGroups = VARS.users.luke.extraGroups;
      hashedPassword = VARS.users.luke.hashedPassword;
      shell = pkgs.zsh;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        VARS.users.admin.sshPubKey
        VARS.users.admin.gpgSshPubKey
      ];
    };

    ${VARS.users.frankie.user} = {
      isNormalUser = VARS.users.frankie.isNormalUser;
      description = VARS.users.frankie.description;
      extraGroups = VARS.users.frankie.extraGroups;
      hashedPassword = VARS.users.frankie.hashedPassword;
      shell = pkgs.zsh;

      packages = with pkgs; [
        # Your packages here
      ];

      openssh.authorizedKeys.keys = [
        VARS.users.admin.sshPubKey
        VARS.users.admin.gpgSshPubKey
      ];
    };
  };
}
