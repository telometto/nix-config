{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.wife.user} = {
    inherit (VARS.users.wife) description isNormalUser extraGroups hashedPassword;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
