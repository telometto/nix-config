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

      sshKeys = [ "B77831B9FEB4A078E8C0A92F5CD3DD364C2622F6" ];
    };

    ssh-agent = {
      enable = true;

      addKeysToAgent = "yes";
    };

    #kdeconnect.enable = true; # Plasma 5
  };
}