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

      sshKeys = [ "727A831B39D2FAC421617C2C203BF5C382E3B60A" ];
    };

    ssh-agent = {
      enable = true;

      addKeysToAgent = "yes";
    };

    #kdeconnect.enable = true; # Plasma 5
  };
}
