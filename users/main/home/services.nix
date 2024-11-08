{ config, lib, pkgs, myVars, ... }:

{
  services = {
    gpg-agent = {
      enable = true;

      enableSshSupport = true;
      enableExtraSocket = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableScDaemon = false; # Smartcard

      #sshKeys = [ "" ];
    };

    #kdeconnect.enable = true;
  };
}
